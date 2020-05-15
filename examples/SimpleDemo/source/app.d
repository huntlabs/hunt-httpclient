import std.stdio;

import hunt.httpclient;
import hunt.logging.ConsoleLogger;
import core.time;

void main() {
    // testGet1();
    // testGet2();
    // testPost();

    // testWithHeaders();
    testUploading();
}

void testGet1() {
    // string name = HttpClient.get("http://10.1.222.110/test.json")["name"];
    // trace(name);

    // string content = HttpClient.get("http://10.1.222.110/").bodyContent();
    // trace(content);

    Response res = HttpClient.get("http://10.1.222.110/");
    HttpField[] headers = res.headers();
    foreach (HttpField header; headers) {
        trace(header.toString());
    }

    trace(res.header("Server")[0]);
}

void testGet2() {
    Response res = HttpClient.request()
        .timeout(3.seconds)
        .get("http://10.1.222.110:8080/");
    HttpField[] headers = res.headers();
    foreach (HttpField header; headers) {
        trace(header.toString());
    }

    trace(res.header("Server")[0]);
}

void testPost() {
    Response res = HttpClient.post("http://10.1.222.110:8080/",
            ["username": "Administrator", "password": "hunt@@2020"]);

    string content = res.bodyContent();
    trace(content);
}

void testWithHeaders() {
    Response res = HttpClient.request()
        .timeout(3.seconds)
        .retry(3, 3.seconds)
        .withHeaders(["X-First": "foo", "X-Second":"bar"])
        .post("http://10.1.222.110:8080/", ["name":"Taylor"]);

    string content = res.bodyContent();
    trace(content);        
}

void testUploading() {
    
    Response res = HttpClient.request()
        .attach("dub", "dub.json")
        // .attach("source", "source/app.d")
        .formData(["name" : "Hunt-HTTP"])
        .post("http://10.1.222.110:8080/");

    string content = res.bodyContent();
    trace(content); 
}

