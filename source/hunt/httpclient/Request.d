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

    private string _contentType = MimeType.TEXT_PLAIN_VALUE;
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
        foreach(string key, string value; headers) {
            _headers[key] = value;
        }
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
        if(_timeout > Duration.zero) {
            options.getTcpConfiguration().setIdleTimeout(_timeout);
            options.getTcpConfiguration().setConnectTimeout(_timeout);
        }

        HuntHttpClient client = new HuntHttpClient(options);
        scope (exit) {
            client.close();
        }

        RequestBuilder builder = new RequestBuilder();

        if(_headers !is null) {
            foreach(string name, string value; _headers) {
                builder.addHeader(name, value);
            }
        }

        HttpClientRequest request = builder.url(url).build();
        HttpClientResponse response = client.newCall(request).execute();

        return new Response(response);
    }

    Response post(string url) {
        string contentType = _contentType;
        HttpBody httpBody;

        if(_bodyFormat == BodyFormat.Multipart) {
            MultipartBody.Builder builder = new MultipartBody.Builder();

            foreach(ref PendingFile file; _pendingFiles) {
                string mimeType = _mimeUtil.getMimeByExtension(file.filename);
                if(mimeType.empty)
                    mimeType = MimeType.TEXT_PLAIN_VALUE;

                builder.addFormDataPart(file.name, file.filename, 
                    HttpBody.createFromFile(mimeType, file.filename));

                // TODO: Tasks pending completion -@zhangxueping at 2020-05-15T16:41:19+08:00
                // Add headers

            }

            foreach(string key, string value; _formData) {
                builder.addFormDataPart(key, value, MimeType.TEXT_PLAIN_VALUE);
            }

            // builder.addFormDataPart("title", "Putao Logo", MimeType.TEXT_PLAIN_VALUE);

            httpBody = builder.build();
        } else {

        }
        
        return post(url, httpBody);
    }

    Response post(string url, string[string] data) {
        assert(data !is null, "No data avaliable!");

        UrlEncoded encoder = new UrlEncoded;
        foreach(string name, string value; data) {
            encoder.put(name, value);
        }
        string content = encoder.encode();
        return post(url, MimeType.APPLICATION_X_WWW_FORM_VALUE, cast(const(ubyte)[])content);
    }

    Response post(string url, JSONValue json) {
        return post(url, MimeType.APPLICATION_JSON_VALUE, cast(const(ubyte)[])json.toString());
    } 

    Response post(string url, string contentType, const(ubyte)[] content) {
        Response res;
        .retry(_tries, (int attempts) {
                res = doPost(url, contentType, content);
            }, 
            _retryDelay);
        return res;
    }

    private Response doPost(string url, string contentType, const(ubyte)[] content) {
        HttpBody hb = HttpBody.create(contentType, content);
        RequestBuilder builder = new RequestBuilder();

        return doPost(url, hb);
    }

    Response post(string url, HttpBody httpBody) {
        Response res;

        .retry(_tries, (int attempts) {
                res = doPost(url, httpBody);
            }, 
            _retryDelay);

        return res;
    }

    private Response doPost(string url, HttpBody httpBody) {
        HttpClientOptions options = new HttpClientOptions();
        if(_timeout > Duration.zero) {
            options.getTcpConfiguration().setIdleTimeout(_timeout);
            options.getTcpConfiguration().setConnectTimeout(_timeout);
        }

        HuntHttpClient client = new HuntHttpClient(options);
        scope (exit) {
            client.close();
        }

        RequestBuilder builder = new RequestBuilder();

        if(_headers !is null) {
            foreach(string name, string value; _headers) {
                builder.addHeader(name, value);
            }
        }

        HttpClientRequest request = builder.url(url).post(httpBody).build();
        HttpClientResponse response = client.newCall(request).execute();

        return new Response(response);
    }
}

/**
 * Retry an operation a given number of times.
 */
private void retry(int times, Action1!int handler, Duration delay = Duration.zero, 
    Func1!(Exception, bool) precondition = null) {

    assert(handler !is null, "The handler can't be null");
    int attempts = 0;

    while(true) {
        attempts++;

        try {
            handler(attempts);
            break;
        } catch(Exception ex) {
            version(HUNT_HTTP_DEBUG) tracef("Retrying %d / %d", attempts, times);
            if(attempts >= times || precondition !is null && !precondition(ex)) {
                throw ex;
            }

            if(delay > Duration.zero) {
                Thread.sleep(delay);
            }
        }
    }
}