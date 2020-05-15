module hunt.httpclient.PendingRequest;

import hunt.http.client;
import hunt.httpclient.Response : Response;
import hunt.logging.ConsoleLogger;

import core.time;

private alias HuntHttpClient = hunt.http.client.HttpClient.HttpClient;

/**
 * 
 */
class PendingRequest {

    private string[string] _headers;
    private Duration _connectionTimeout;

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

    PendingRequest withHeaders(string[string] headers) {
        _headers = headers;
        return this;
    }

    PendingRequest timeout(Duration dur) {
        _connectionTimeout = dur;
        return this;
    }

    PendingRequest retry(int timers, Duration delay) {
        _tries = timers;
        _retryDelay = delay;
        return this;
    }

    Response post(string url, string[string] data = null) {
        UrlEncoded encoder = new UrlEncoded;
        foreach(string name, string value; data) {
            encoder.put(name, value);
        }
        
        string content = encoder.encode();
        // return post(url, MimeType.APPLICATION_X_WWW_FORM_VALUE, cast(const(ubyte)[])content);

        Response res;
        .retry(_tries, (int attempts) {
                res = post(url, MimeType.APPLICATION_X_WWW_FORM_VALUE, cast(const(ubyte)[])content);
            }, _retryDelay);
        return res;
    }

    private Response post(string url, string contentType, const(ubyte)[] content) {
        HttpClientOptions options = new HttpClientOptions();
        options.getTcpConfiguration().setIdleTimeout(_connectionTimeout);
        options.getTcpConfiguration().setConnectTimeout(_connectionTimeout);

        HuntHttpClient client = new HuntHttpClient(options);
        scope (exit) {
            client.close();
        }

        HttpBody hb = HttpBody.create(contentType, content);
        RequestBuilder builder = new RequestBuilder();

        if(_headers !is null) {
            foreach(string name, string value; _headers) {
                builder.addHeader(name, value);
            }
        }

        HttpClientRequest request = builder.url(url).post(hb).build();
        HttpClientResponse response = client.newCall(request).execute();

        return new Response(response);
    }

}

import hunt.Functions;
import core.thread;

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