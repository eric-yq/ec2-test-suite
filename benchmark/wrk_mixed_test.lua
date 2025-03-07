math.randomseed(os.time())

request = function()
  local method
  -- 75% GET, 25% POST
  if math.random() < 0.75 then
    method = "GET"
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

end

