# 1. app 和 load 在不同实例，结果可能受网络延时不同而受一定影响
## c7g.xlarge
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 100                 |
| Max Cores usage (%)       | 399                 |
| Max Working Set (MB)      | 182                 |
| Max Private Memory (MB)   | 288                 |
| Build Time (ms)           | 6,142               |
| Start Time (ms)           | 229                 |
| Published Size (KB)       | 108,094             |
| Symbols Size (KB)         | 24                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 100                 |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 19                  |
| Max Cores usage (%)       | 151                 |
| Max Working Set (MB)      | 47                  |
| Max Private Memory (MB)   | 136                 |
| Build Time (ms)           | 3,569               |
| Start Time (ms)           | 96                  |
| Published Size (KB)       | 72,281              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 23                  |
| First Request (ms)        | 137                 |
| Requests                  | 4,104,067           |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 0.22                |
| Latency 75th (ms)         | 0.26                |
| Latency 90th (ms)         | 0.30                |
| Latency 95th (ms)         | 0.33                |
| Latency 99th (ms)         | 0.41                |
| Mean latency (ms)         | 0.23                |
| Max latency (ms)          | 11.77               |
| Requests/sec              | 68,402              |
| Requests/sec (max)        | 76,536              |
| Read throughput (MB/s)    | 246.06              |

## c8g.xlarge
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 100                 |
| Max Cores usage (%)       | 399                 |
| Max Working Set (MB)      | 187                 |
| Max Private Memory (MB)   | 301                 |
| Build Time (ms)           | 4,814               |
| Start Time (ms)           | 189                 |
| Published Size (KB)       | 108,240             |
| Symbols Size (KB)         | 24                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 100                 |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 24                  |
| Max Cores usage (%)       | 194                 |
| Max Working Set (MB)      | 47                  |
| Max Private Memory (MB)   | 135                 |
| Build Time (ms)           | 3,530               |
| Start Time (ms)           | 67                  |
| Published Size (KB)       | 72,281              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 26                  |
| First Request (ms)        | 111                 |
| Requests                  | 5,290,620           |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 0.17                |
| Latency 75th (ms)         | 0.21                |
| Latency 90th (ms)         | 0.24                |
| Latency 95th (ms)         | 0.26                |
| Latency 99th (ms)         | 0.33                |
| Mean latency (ms)         | 0.18                |
| Max latency (ms)          | 14.81               |
| Requests/sec              | 88,177              |
| Requests/sec (max)        | 100,357             |
| Read throughput (MB/s)    | 317.19              |


## c8i.xlarge
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 98                  |
| Max Cores usage (%)       | 391                 |
| Max Working Set (MB)      | 1,286               |
| Max Private Memory (MB)   | 1,413               |
| Build Time (ms)           | 4,098               |
| Start Time (ms)           | 231                 |
| Published Size (KB)       | 99,385              |
| Symbols Size (KB)         | 24                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 98                  |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 18                  |
| Max Cores usage (%)       | 146                 |
| Max Working Set (MB)      | 47                  |
| Max Private Memory (MB)   | 135                 |
| Build Time (ms)           | 3,520               |
| Start Time (ms)           | 77                  |
| Published Size (KB)       | 72,281              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 20                  |
| First Request (ms)        | 106                 |
| Requests                  | 3,656,422           |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 0.25                |
| Latency 75th (ms)         | 0.29                |
| Latency 90th (ms)         | 0.34                |
| Latency 95th (ms)         | 0.37                |
| Latency 99th (ms)         | 0.45                |
| Mean latency (ms)         | 0.26                |
| Max latency (ms)          | 5.49                |
| Requests/sec              | 60,941              |
| Requests/sec (max)        | 69,579              |
| Read throughput (MB/s)    | 219.22              |

# 2. app 和 load 在同一个实例，结果不受网络延迟影响
## c7g
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 86                  |
| Max Cores usage (%)       | 344                 |
| Max Working Set (MB)      | 173                 |
| Max Private Memory (MB)   | 286                 |
| Build Time (ms)           | 4,560               |
| Start Time (ms)           | 226                 |
| Published Size (KB)       | 107,947             |
| Symbols Size (KB)         | 23                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 100                 |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 24                  |
| Max Cores usage (%)       | 95                  |
| Max Working Set (MB)      | 46                  |
| Max Private Memory (MB)   | 135                 |
| Build Time (ms)           | 5,568               |
| Start Time (ms)           | 91                  |
| Published Size (KB)       | 78,542              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 100                 |
| First Request (ms)        | 151                 |
| Requests                  | 2,294,294           |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 0.09                |
| Latency 75th (ms)         | 0.12                |
| Latency 90th (ms)         | 0.15                |
| Latency 95th (ms)         | 0.19                |
| Latency 99th (ms)         | 0.30                |
| Mean latency (ms)         | 0.10                |
| Max latency (ms)          | 16.84               |
| Requests/sec              | 38,239              |
| Requests/sec (max)        | 64,794              |
| Read throughput (MB/s)    | 137.55              |

## c8g
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 84                  |
| Max Cores usage (%)       | 335                 |
| Max Working Set (MB)      | 184                 |
| Max Private Memory (MB)   | 290                 |
| Build Time (ms)           | 3,461               |
| Start Time (ms)           | 193                 |
| Published Size (KB)       | 108,132             |
| Symbols Size (KB)         | 24                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 99                  |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 24                  |
| Max Cores usage (%)       | 94                  |
| Max Working Set (MB)      | 46                  |
| Max Private Memory (MB)   | 127                 |
| Build Time (ms)           | 4,151               |
| Start Time (ms)           | 68                  |
| Published Size (KB)       | 78,542              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 99                  |
| First Request (ms)        | 111                 |
| Requests                  | 3,548,148           |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 0.06                |
| Latency 75th (ms)         | 0.07                |
| Latency 90th (ms)         | 0.09                |
| Latency 95th (ms)         | 0.11                |
| Latency 99th (ms)         | 0.19                |
| Mean latency (ms)         | 0.07                |
| Max latency (ms)          | 18.86               |
| Requests/sec              | 59,135              |
| Requests/sec (max)        | 84,409              |
| Read throughput (MB/s)    | 212.73              |

## c8i
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 88                  |
| Max Cores usage (%)       | 352                 |
| Max Working Set (MB)      | 1,296               |
| Max Private Memory (MB)   | 1,414               |
| Build Time (ms)           | 2,874               |
| Start Time (ms)           | 213                 |
| Published Size (KB)       | 99,294              |
| Symbols Size (KB)         | 24                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 98                  |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 23                  |
| Max Cores usage (%)       | 91                  |
| Max Working Set (MB)      | 47                  |
| Max Private Memory (MB)   | 127                 |
| Build Time (ms)           | 3,715               |
| Start Time (ms)           | 70                  |
| Published Size (KB)       | 72,281              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 98                  |
| First Request (ms)        | 105                 |
| Requests                  | 4,047,978           |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 0.05                |
| Latency 75th (ms)         | 0.06                |
| Latency 90th (ms)         | 0.08                |
| Latency 95th (ms)         | 0.09                |
| Latency 99th (ms)         | 0.14                |
| Mean latency (ms)         | 0.06                |
| Max latency (ms)          | 16.22               |
| Requests/sec              | 67,466              |
| Requests/sec (max)        | 86,263              |
| Read throughput (MB/s)    | 242.69              |