-- File: http.moon
local *

import insert from table

POST_HEADERS =
  "Content-Type": "application/json; charset=UTF-8"
  "Content-Encoding": "identity"

baseAPI = "http://misoshiki-bot-misoshiki.44fs.preview.openshiftapps.com/"

----------------------------------
-- Class: AsyncHTTPRequest
----------------------------------
class AsyncHTTPRequest
  ----------------------------------
  -- Method: new
  -- Creates a new instance of <AsyncHTTPRequest> which will be used in <AsyncHTTPQueue>.
  --
  -- Parameters:
  --   endpoint - The endpoint you want to call.
  --   data - The data you want to transmit to the endpoint. Nil for a GET request.
  --   headers - Extra headers you want to add to the request.
  --   callback - A function which will receive the result of the call.
  --
  -- Returns:
  --  A new instance of <AsyncHTTPRequest>.
  --
  -- See Also:
  --  <AsyncHTTPQueue>
  --
  ----------------------------------
  new: (endpoint, data, headers, callback) =>
    @url = baseAPI .. endpoint
    @callback = callback
    @headers = headers
    @data = data
    @running = false
    @processed = false


----------------------------------
--  Class: AsyncHTTPQueue
----------------------------------
class AsyncHTTPQueue
  ----------------------------------
  -- Method: new
  -- Creates a new instance of <AsyncHTTPQueue>.
  --
  -- Returns:
  --   A new instance of <AsyncHTTPQueue>.
  ----------------------------------
  new: =>
    @requests = {}
  ----------------------------------
  -- Method: get
  -- Adds a new GET request.
  --
  -- Parameters:
  --   endpoint - The endpoint you want to call.
  --   callback - A function which will receive the result of the call.
  --
  -- See Also:
  --   <AsyncHTTPQueue::post>
  ----------------------------------
  get: (endpoint, callback) =>
    insert @requests, AsyncHTTPRequest  endpoint,
                                        nil,
                                        nil,
                                        callback
  ----------------------------------
  -- Method: post
  -- Adds a new POST request.
  --
  -- Parameters:
  --   endpoint - The endpoint you want to call.
  --   data - The data you want to transmit to the endpoint.
  --   callback - A function which will receive the result of the call.
  --
  -- See Also:
  --   <AsyncHTTPQueue::get>
  ----------------------------------
  post: (endpoint, data, callback) =>
    insert @requests, AsyncHTTPRequest  endpoint,
                                        data,
                                        POST_HEADERS,
                                        callback
  ----------------------------------
  -- Method: startRequestsThread
  -- A Titanium Thread which will start the HTTP requests.
  --
  -- Returns:
  --   A Titanium Thread.
  ----------------------------------
  startRequestsThread: =>
    Thread ->
      while true
        sleep 0
        for k,v in pairs @requests do
          if not v.running
            v.running = true
            http.request v.url, v.data, v.headers
  ----------------------------------
  -- Method: handleRequestsThread
  -- A Titanium Thread which will handle the HTTP responses.
  --
  -- Returns:
  --  A Titanium Thread.
  ----------------------------------
  handleResponsesThread: =>
    Thread ->
      while true
        evt = {coroutine.yield "http_success"}
        url,found = evt[2],false
        for k,v in pairs @requests
          if not found
            if v.url == url and not v.processed
              found = true
              handle = evt[3]
              content = handle.readAll!
              handle\close!
              pcall(-> v.callback content)
              v.processed = true

{
  :AsyncHTTPQueue
  :AsyncHTTPRequest
}
