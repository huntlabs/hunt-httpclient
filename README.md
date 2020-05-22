# Hunt HttpClient
Hunt HttpClient is a tool library for sending HTTP requests to Web service communications. provides a very good development experience for developers.

## Simple code for get
```D
string content = Http.get("http://api.example.com/user/1").content();

writeln(content);
```

## Simple  code for post
```D
auto response = Http.post("http://api.example.com/auto",
        ["username": "admin", "password": "hunt@@2020"]);

string content = response.content();

writeln(content);
```

### See also
[1] https://laravel.com/docs/7.x/http-client
