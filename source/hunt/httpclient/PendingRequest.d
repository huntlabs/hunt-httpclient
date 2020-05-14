module hunt.httpclient.PendingRequest;

import hunt.http.client;
import hunt.httpclient.Response : Response;

private alias HuntHttpClient = hunt.http.client.HttpClient.HttpClient;

/**
 * 
 */
class PendingRequest {

    private string[string] _headers;

    this() {

    }

    PendingRequest withHeaders(string[string] headers) {
        _headers = headers;
        return this;
    }

    Response post(string url, string[string] data = null) {
        UrlEncoded encoder = new UrlEncoded;
        foreach(string name, string value; data) {
            encoder.put(name, value);
        }
        
        string content = encoder.encode();
        return post(url, MimeType.APPLICATION_X_WWW_FORM_VALUE, cast(const(ubyte)[])content);
    }

    private Response post(string url, string contentType, const(ubyte)[] content) {
        HuntHttpClient client = new HuntHttpClient();
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