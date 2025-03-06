math.randomseed(os.time())

-- 计数器用于验证请求比例
local get_count = 0
local post_count = 0

init = function()
  get_count = 0
  post_count = 0
end

request = function()
  local method
  -- 75% GET, 25% POST
  if math.random() < 0.75 then
    method = "GET"
    get_count = get_count + 1
    local queryString = string.rep("a", 120)
    return wrk.format(method, "/get?" .. queryString)
  else
    method = "POST"
    post_count = post_count + 1
    local headers = {}
    headers["Content-Type"] = "application/x-www-form-urlencoded"
    return wrk.format(method, "/post", headers, string.rep("B", 128))
  end
end

done = function(summary, latency, requests)
  -- 统计 RPS 和 Latency
  io.write("\n--- Performnce Metric ---\n")
  rps = summary.requests / (summary.duration/1000/1000)
  io.write(string.format("%s, RPS, %g, %d, %d, %d, %d\n", "$INSTANCE_TYPE", rps, latency:percentile(50),latency:percentile(90),latency:percentile(99),latency:percentile(99.99)))
   
  -- 统计 GET 和 POST
  local total = get_count + post_count
  local get_ratio = get_count / total * 100
  local post_ratio = post_count / total * 100
  io.write("\n--- Request Distribution ---\n")
  io.write(string.format("GET requests: %d (%.2f%%)\n", get_count, get_ratio))
  io.write(string.format("POST requests: %d (%.2f%%)\n", post_count, post_ratio))
  io.write(string.format("GET:POST ratio = %.2f:1\n", get_count/post_count))
  io.write("-------------------------\n")
end

