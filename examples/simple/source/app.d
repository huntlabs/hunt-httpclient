import std.stdio;

import hunt.httpclient;
import hunt.logging.ConsoleLogger;
import std.conv;

import hunt.net.EventLoopPool;

enum string Host = "10.1.23.222";
enum ushort Port = 8080;

void main() {
    testGet1();
    // testGet2();
    // testPost1();
    // testPost2();

    // testWithHeaders();
    // testUploading();

    // testGetHttps();

    getchar();

    shutdownEventLoopPool();

}

void testGet1() {
    // string name = Http.get("http://" ~ Host ~ "/test.json")["name"];
    // trace(name);

    // string content = Http.get("http://" ~ Host ~ "/").content();
    // trace(content);

    Response res = Http.get("http://" ~ Host ~ "/");
    HttpField[] headers = res.headers();
    foreach (HttpField header; headers) {
        trace(header.toString());
    }

    trace(res.header("Server")[0]);

    string content =  res.content();
    info(content);    
}


void testGet2() {
    Response res = Http
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
            ["username": "Administrator", "password": `abcd 1234567890ABCD1234~!@#$%^&*()_+{}<>?:"[]\|';/.,`]);

    string content = res.content();
    trace(content);
}

void testPost2() {
    Response res = Http.asJson()
        .post("http://" ~ Host ~ ":" ~ Port.to!string() ~ "/");

    string content = res.content();
    trace(content);
}

void testWithHeaders() {
    Response res = Http.retry(3, 3.seconds)
        .timeout(3.seconds)
        .withHeaders(["X-First": "foo", "X-Second":"bar"])
        .post("http://" ~ Host ~ ":" ~ Port.to!string() ~ "/", ["name":"Taylor"]);

    string content = res.content();
    trace(content);        
}

void testUploading() {
    
    Response res = Http.attach("dub", "dub.json")
        // .attach("source", "source/app.d")
        .formData(["name" : "Hunt-HTTP"])
        .post("http://" ~ Host ~ ":" ~ Port.to!string() ~ "/");

    string content = res.content();
    trace(content); 
}


void testGetHttps() {

    Response res = Http.get("https://www.baidu.com");
    HttpField[] headers = res.headers();
    foreach (HttpField header; headers) {
        trace(header.toString());
    }
}

