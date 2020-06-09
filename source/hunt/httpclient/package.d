module hunt.httpclient;

public import hunt.httpclient.Request;
public import hunt.httpclient.Response;

public import hunt.http.HttpField;

public import core.time;
public import std.json;


Request Http() {
    return new Request();
}