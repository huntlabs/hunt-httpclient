module hunt.httpclient.Request;

import hunt.Functions;
import hunt.http.client;
import hunt.httpclient.Response : Response;
import hunt.logging.ConsoleLogger;
import hunt.util.MimeTypeUtils;

import std.json;
import std.range;
import core.thread;
import core.time;

private alias HuntHttpClient = hunt.http.client.HttpClient.HttpClient;

private struct PendingFile {
    string name;
    // const(ubyte)[] contents;
    string filename;
    string[string] headers;
}

private struct BodyFormat {
    enum string JSON = "json";
    enum string FormParams = "form_params";
    enum string Multipart = "multipart";
}

/**
 * 
 */
class Request {

    private string _contentType; // = MimeType.TEXT_PLAIN_VALUE;
    private string[string] _headers;
    private Duration _timeout;
    private PendingFile[] _pendingFiles;
    private string _bodyFormat;
    private MimeTypeUtils _mimeUtil = new MimeTypeUtils();
    private string[string] _formData;

    /**
     * The number of times to try the request.
     */
    private int _tries = 1;

    /**
     * The number of milliseconds to wait between retries.
     */
    private Duration _retryDelay = 100.msecs;

    this() {
    }

    /**
     * Indicate the request contains JSON.
     */
    Request asJson() {
        _bodyFormat = BodyFormat.JSON;
        contentType(MimeType.APPLICATION_JSON_VALUE);
        return this;
    }

    /**
     * Indicate the request contains form parameters.
     */
    Request asForm() {
        _bodyFormat = BodyFormat.FormParams;
        contentType(MimeType.APPLICATION_X_WWW_FORM_VALUE);
        return this;
    }

    /**
     * Specify the body format of the request.
     */
    Request bodyFormat(string value) {
        _bodyFormat = value;
        return this;
    }

    /**
     * Indicate the request is a multi-part form request.
     */
    Request asMultipart() {
        _bodyFormat = BodyFormat.Multipart;
        return this;
    }

    Request attach(string name, string filename = null, string[string] headers = null) {
        _pendingFiles ~= PendingFile(name, filename, headers);
        asMultipart();
        return this;
    }

    Request formData(string[string] data) {
        _formData = data;
        asMultipart();
        return this;
    }

    /**
     * Indicate the type of content that should be returned by the server.
     */
    Request accept(string contentType) {
        _headers[HttpHeader.ACCEPT.toString()] = contentType;
        return this;
    }

    /**
     * Indicate that JSON should be returned by the server.
     */
    Request acceptJson(string contentType) {
        return accept(MimeType.APPLICATION_JSON_VALUE);
    }

    /**
     * Specify the request's content type.
     */
    Request contentType(string value) {
        _contentType = value;
        return this;
    }

    Request withHeaders(string[string] headers) {
        foreach (string key, string value; headers) {
            _headers[key] = value;
        }
        return this;
    }

    Request withCookies(Cookie[] cookies...) {
        string cookie = HttpHeader.COOKIE.toString();
        _headers[cookie] = generateCookies(cookies);
        return this;
    }

    /**
     * Specify an authorization token for the request.
     */
    Request withToken(string value, string type = "Bearer") {
        _headers[HttpHeader.AUTHORIZATION.toString()] = type ~ " " ~ value;
        return this;
    }

    Request timeout(Duration dur) {
        _timeout = dur;
        return this;
    }

    Request retry(int timers, Duration delay) {
        _tries = timers;
        _retryDelay = delay;
        return this;
    }

    Response get(string url) {
        Response res;
        .retry(_tries, (int attempts) { res = doGet(url); }, _retryDelay);
        return res;
    }

    private Response doGet(string url) {
        HttpClientOptions options = new HttpClientOptions();
        if (_timeout > Duration.zero) {
            options.getTcpConfiguration().setIdleTimeout(_timeout);
            options.getTcpConfiguration().setConnectTimeout(_timeout);
        }

        HuntHttpClient client = new HuntHttpClient(options);
        scope (exit) {
            client.close();
        }

        RequestBuilder builder = new RequestBuilder();

        if (_headers !is null) {
            foreach (string name, string value; _headers) {
                builder.addHeader(name, value);
            }
        }

        HttpClientRequest request = builder.url(url).build();
        HttpClientResponse response = client.newCall(request).execute();

        return new Response(response);
    }

    /* #region private methods  */

    private HttpBody buildBody() {
        HttpBody httpBody;
        if (_bodyFormat == BodyFormat.Multipart) {
            MultipartBody.Builder builder = new MultipartBody.Builder();

            foreach (string key, string value; _formData) {
                builder.addFormDataPart(key, value, MimeType.TEXT_PLAIN_VALUE);
            }

            foreach (ref PendingFile file; _pendingFiles) {
                string mimeType = _mimeUtil.getMimeByExtension(file.filename);
                if (mimeType.empty)
                    mimeType = MimeType.TEXT_PLAIN_VALUE;

                builder.addFormDataPart(file.name, file.filename,
                        HttpBody.createFromFile(mimeType, file.filename));

                // TODO: Tasks pending completion -@zhangxueping at 2020-05-15T16:41:19+08:00
                // Add headers
            }

            httpBody = builder.build();
        } else {
            httpBody = HttpBody.create(_contentType, cast(const(ubyte)[]) null);
        }

        return httpBody;
    }

    private Response perform(string url, HttpBody httpBody, HttpMethod method = HttpMethod.POST) {
        HttpClientOptions options = new HttpClientOptions();
        if (_timeout > Duration.zero) {
            options.getTcpConfiguration().setIdleTimeout(_timeout);
            options.getTcpConfiguration().setConnectTimeout(_timeout);
        }

        HuntHttpClient client = new HuntHttpClient(options);
        scope (exit) {
            client.close();
        }

        RequestBuilder builder = new RequestBuilder();

        if (_headers !is null) {
            foreach (string name, string value; _headers) {
                builder.addHeader(name, value);
            }
        }

        builder.url(url);

        if(method == HttpMethod.POST) 
            builder.post(httpBody);
        else if(method == HttpMethod.PUT) 
            builder.put(httpBody);
        else if(method == HttpMethod.DELETE) 
            builder.del(httpBody);
        else if(method == HttpMethod.PATCH) 
            builder.patch(httpBody);
        else
            throw new Exception("Unsupported method: " ~ method.toString());

        HttpClientRequest request = builder.build();
        HttpClientResponse response = client.newCall(request).execute();

        return new Response(response);
    }

    /* #endregion */
    
    /* #region POST */

    Response post(string url) {
        return post(url, buildBody());
    }

    Response post(string url, string[string] data) {
        assert(data !is null, "No data avaliable!");

        UrlEncoded encoder = new UrlEncoded(UrlEncodeStyle.HtmlForm);
        foreach (string name, string value; data) {
            encoder.put(name, value);
        }
        string content = encoder.encode();
        if (_contentType.empty)
            _contentType = MimeType.APPLICATION_X_WWW_FORM_VALUE;
        return post(url, _contentType, cast(const(ubyte)[]) content);
    }

    Response post(string url, JSONValue json) {
        if (_contentType.empty)
            _contentType = MimeType.APPLICATION_JSON_VALUE;
        return post(url, _contentType, cast(const(ubyte)[]) json.toString());
    }

    Response post(string url, string contentType, const(ubyte)[] content) {
        Response res;
        .retry(_tries, 
            (int attempts) { 
                res = perform(url, HttpBody.create(contentType, content), HttpMethod.POST); 
            }, 
            _retryDelay);
        return res;
    }

    Response post(string url, HttpBody httpBody) {
        Response res;
        .retry(_tries, 
            (int attempts) { 
                res = perform(url, httpBody, HttpMethod.POST); 
            }, 
            _retryDelay);
        return res;
    }

    /* #endregion */


    /* #region PUT */

    Response put(string url) {
        return put(url, buildBody());
    }

    Response put(string url, string[string] data) {
        assert(data !is null, "No data avaliable!");

        UrlEncoded encoder = new UrlEncoded(UrlEncodeStyle.HtmlForm);
        foreach (string name, string value; data) {
            encoder.put(name, value);
        }
        string content = encoder.encode();
        if (_contentType.empty)
            _contentType = MimeType.APPLICATION_X_WWW_FORM_VALUE;
        return put(url, _contentType, cast(const(ubyte)[]) content);
    }

    Response put(string url, JSONValue json) {
        if (_contentType.empty)
            _contentType = MimeType.APPLICATION_JSON_VALUE;
        return put(url, _contentType, cast(const(ubyte)[]) json.toString());
    }

    Response put(string url, string contentType, const(ubyte)[] content) {
        Response res;
        .retry(_tries, 
            (int attempts) { 
                res = perform(url, HttpBody.create(contentType, content), HttpMethod.PUT); 
            }, 
            _retryDelay);
        return res;
    }

    Response put(string url, HttpBody httpBody) {
        Response res;
        .retry(_tries, 
            (int attempts) { 
                res = perform(url, httpBody, HttpMethod.PUT); 
            }, 
            _retryDelay);
        return res;
    }

    /* #endregion */


    /* #region DELETE */

    Response del(string url) {
        return del(url, buildBody());
    }

    Response del(string url, string[string] data) {
        assert(data !is null, "No data avaliable!");

        UrlEncoded encoder = new UrlEncoded(UrlEncodeStyle.HtmlForm);
        foreach (string name, string value; data) {
            encoder.put(name, value);
        }
        string content = encoder.encode();
        if (_contentType.empty)
            _contentType = MimeType.APPLICATION_X_WWW_FORM_VALUE;
        return del(url, _contentType, cast(const(ubyte)[]) content);
    }

    Response del(string url, JSONValue json) {
        if (_contentType.empty)
            _contentType = MimeType.APPLICATION_JSON_VALUE;
        return del(url, _contentType, cast(const(ubyte)[]) json.toString());
    }

    Response del(string url, string contentType, const(ubyte)[] content) {
        Response res;
        .retry(_tries, 
            (int attempts) { 
                res = perform(url, HttpBody.create(contentType, content), HttpMethod.DELETE); 
            }, 
            _retryDelay);
        return res;
    }

    Response del(string url, HttpBody httpBody) {
        Response res;
        .retry(_tries, 
            (int attempts) { 
                res = perform(url, httpBody, HttpMethod.DELETE); 
            }, 
            _retryDelay);
        return res;
    }

    /* #endregion */
    

    /* #region PATCH */

    Response patch(string url) {
        return patch(url, buildBody());
    }

    Response patch(string url, string[string] data) {
        assert(data !is null, "No data avaliable!");

        UrlEncoded encoder = new UrlEncoded(UrlEncodeStyle.HtmlForm);
        foreach (string name, string value; data) {
            encoder.put(name, value);
        }
        string content = encoder.encode();
        if (_contentType.empty)
            _contentType = MimeType.APPLICATION_X_WWW_FORM_VALUE;
        return patch(url, _contentType, cast(const(ubyte)[]) content);
    }

    Response patch(string url, JSONValue json) {
        if (_contentType.empty)
            _contentType = MimeType.APPLICATION_JSON_VALUE;
        return patch(url, _contentType, cast(const(ubyte)[]) json.toString());
    }

    Response patch(string url, string contentType, const(ubyte)[] content) {
        Response res;
        .retry(_tries, 
            (int attempts) { 
                res = perform(url, HttpBody.create(contentType, content), HttpMethod.PATCH); 
            }, 
            _retryDelay);
        return res;
    }

    Response patch(string url, HttpBody httpBody) {
        Response res;
        .retry(_tries, 
            (int attempts) { 
                res = perform(url, httpBody, HttpMethod.PATCH); 
            }, 
            _retryDelay);
        return res;
    }

    /* #endregion */
}

/**
 * Retry an operation a given number of times.
 */
private void retry(int times, Action1!int handler, Duration delay = Duration.zero,
        Func1!(Exception, bool) precondition = null) {

    assert(handler !is null, "The handler can't be null");
    int attempts = 0;

    while (true) {
        attempts++;

        try {
            handler(attempts);
            break;
        } catch (Exception ex) {
            version (HUNT_HTTP_DEBUG)
                tracef("Retrying %d / %d", attempts, times);
            if (attempts >= times || precondition !is null && !precondition(ex)) {
                throw ex;
            }

            if (delay > Duration.zero) {
                Thread.sleep(delay);
            }
        }
    }
}
