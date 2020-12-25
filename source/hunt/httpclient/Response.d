module hunt.httpclient.Response;

import hunt.http.client;
import hunt.logging.ConsoleLogger;

import std.format;
import std.json;
import std.range;


/**
 * 
 */
class Response {
    private HttpClientResponse _response;
    private string _stringContent;
    private JSONValue _jsonContent;
    // private string[][string] 

    this(HttpClientResponse response) {
        _response = response;
    }

    /**
     * Get the body of the response.
     *
     * @return string
     */
    string content() {
        if(_stringContent.empty() && _response.haveBody()) {
            _stringContent = _response.getBody().toString();
        }
        return _stringContent;
    }

    /**
     * Get the JSON decoded body of the response as an array.
     *
     * @return JSONValue
     */
    JSONValue json() {
        if(_jsonContent == JSONValue.init) {
            string content = content();
            _jsonContent = parseJSON(content);
        }
        return _jsonContent;
    }

    string opIndex(string key) {
        string content = content();
        JSONValue jv;
        try {
            jv = parseJSON(content);
        } catch(Exception ex) {
            warning(ex.msg);
            throw new Exception("The content is not a json.", ex);
        }

        auto itemPtr = key in jv;
        if(itemPtr is null) {
            throw new Exception(format("The key does NOT exist: %s", key));
        } else {
            return jv[key].str;
        }
    }

    string[] header(string name) {
        HttpFields fields = _response.headers();
        return fields.getValuesList(name);
    }

    HttpField[] headers() {
        HttpFields fields = _response.headers();
        return fields.allFields();
    }

    /**
     * Get the status code of the response.
     *
     * @return int
     */
    int status() {
        return _response.getStatus();
    }

    /**
     * Determine if the response code was "OK".
     *
     * @return bool
     */
    bool isOk() {
        return status() == 200;
    }

    /**
     * Determine if the request was successful.
     *
     * @return bool
     */
    bool isSuccessful() {
        int s = status();
        return s >= 200 && s < 300;
    }

    /**
     * Determine if the response was a redirect.
     *
     * @return bool
     */
    bool isRedirect() {
        int s = status();
        return s >= 300 && s < 400;
    }

    /**
     * Determine if the response indicates a client or server error occurred.
     *
     * @return bool
     */
    bool isFailed() {
        return isClientError() || isServerError();
    }

    /**
     * Determine if the response indicates a client error occurred.
     *
     * @return bool
     */
    bool isClientError() {
        int s = status();
        return s >= 400 && s < 500;
    }

    /**
     * Determine if the response indicates a server error occurred.
     *
     * @return bool
     */
    bool isServerError() {
        return status() >= 500;
    }

    Cookie[] cookies() {
        return _response.cookies();
    }
}
