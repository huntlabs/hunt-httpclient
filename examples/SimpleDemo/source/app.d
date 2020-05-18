import std.stdio;

import hunt.httpclient;
import hunt.logging.ConsoleLogger;
import std.conv;

enum string Host = "10.1.222.110";
enum ushort Port = 8080;

void main() {
    // testGet1();
    // testGet2();
    // testPost1();
    testPost2();

    // testWithHeaders();
    // testUploading();
}

void testGet1() {
    // string name = Http.get("http://" ~ Host ~ "/test.json")["name"];
    // trace(name);

    // string content = Http.get("http://" ~ Host ~ "/").bodyContent();
    // trace(content);

    Response res = Http.get("http://" ~ Host ~ "/");
    HttpField[] headers = res.headers();
    foreach (HttpField header; headers) {
        trace(header.toString());
    }

    trace(res.header("Server")[0]);
}

void testGet2() {
    Response res = Http.request()
        .timeout(3.seconds)
        .get("http://" ~ Host ~ ":" ~ Port.to!string() ~ "/");
    HttpField[] headers = res.headers();
    foreach (HttpField header; headers) {
        trace(header.toString());
    }

    trace(res.header("Server")[0]);
}

void testPost1() {
    Response res = Http.post("http://" ~ Host ~ ":" ~ Port.to!string() ~ "/",
            ["username": "Administrator", "password": "hunt@@2020"]);

    string content = res.bodyContent();
    trace(content);
}

void testPost2() {
    Response res = Http.request()
        .asJson()
        .post("http://" ~ Host ~ ":" ~ Port.to!string() ~ "/");

    string content = res.bodyContent();
    trace(content);
}

void testWithHeaders() {
    Response res = Http.request()
        .retry(3, 3.seconds)
        .timeout(3.seconds)
        .withHeaders(["X-First": "foo", "X-Second":"bar"])
        .post("http://" ~ Host ~ ":" ~ Port.to!string() ~ "/", ["name":"Taylor"]);

    string content = res.bodyContent();
    trace(content);        
}

void testUploading() {
    
    Response res = Http.request()
        .attach("dub", "dub.json")
        // .attach("source", "source/app.d")
        .formData(["name" : "Hunt-HTTP"])
        .post("http://" ~ Host ~ ":" ~ Port.to!string() ~ "/");

    string content = res.bodyContent();
    trace(content); 
}

