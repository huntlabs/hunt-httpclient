module hunt.httpclient.HttpClient;

import hunt.http.client;
import hunt.httpclient.Response : Response;
import hunt.httpclient.Request : Request;

private alias HuntHttpClient = hunt.http.client.HttpClient.HttpClient;
// private alias RequestBuilder = HttpClientRequest.Builder;

import std.json;

/**
 * 
 */
struct HttpClient {

    static Response get(string url) {
        HuntHttpClient client = new HuntHttpClient();
        scope (exit) {
            client.close();
        }

        HttpClientRequest request = new RequestBuilder().url(url).build();
        HttpClientResponse response = client.newCall(request).execute();

        return new Response(response);
    }

    static Response post(string url, string contentType, const(ubyte)[] content) {
        HuntHttpClient client = new HuntHttpClient();
        scope (exit) {
            client.close();
        }

        HttpBody hb = HttpBody.create(contentType, content);

        HttpClientRequest request = new RequestBuilder()
                .url(url).post(hb).build();

        HttpClientResponse response = client.newCall(request).execute();

        return new Response(response);
    }

    static Response post(string url, string[string] data) {
        UrlEncoded encoder = new UrlEncoded;
        foreach(string name, string value; data) {
            encoder.put(name, value);
        }
        
        string content = encoder.encode();
        return post(url, MimeType.APPLICATION_X_WWW_FORM_VALUE, cast(const(ubyte)[])content);
    }

    static Response post(string url, JSONValue json) {
        return post(url, MimeType.APPLICATION_JSON_VALUE, cast(const(ubyte)[])json.toString());
    }

    static Request request() {
        return new Request();
    }

    // static RequestBuilder attach(RequestBuilder request) {
    //     if(request is null)
    //         request = new HttpClientRequest();
    //     return request;
    // }

}
