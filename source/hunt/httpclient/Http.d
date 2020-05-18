module hunt.httpclient.Http;

import hunt.http.client;
import hunt.httpclient.Response : Response;
import hunt.httpclient.Request : Request;

import std.json;

/**
 * 
 */
struct Http {

    static Response get(string url) {
        return request().get(url);
    }

    static Response post(string url, string contentType, const(ubyte)[] content) {
        return request().post(url, contentType, content);
    }

    static Response post(string url, string data) {
        return post(url, MimeType.TEXT_PLAIN_VALUE, cast(const(ubyte)[])data);
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
}
