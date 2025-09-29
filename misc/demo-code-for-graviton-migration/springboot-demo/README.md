# Spring Boot Menu Config API

基于Spring Boot 2.3.7.RELEASE的菜单配置API应用，提供缓存功能和JMeter压测方案。

## 项目结构
```
springboot-demo/
├── src/main/java/com/example/
│   ├── Application.java              # 主应用类
│   ├── controller/ConfigController.java  # 控制器
│   └── service/ConfigService.java    # 服务类（含缓存）
├── src/main/resources/
│   └── application.yml               # 配置文件
├── pom.xml                          # Maven配置
├── build-and-run.sh                 # 构建启动脚本
├── test-plan.jmx                    # JMeter测试计划
├── jmeter-setup.sh                  # JMeter环境安装脚本
└── run-jmeter-test.sh               # JMeter压测执行脚本
```

## 构建和启动

### 1. 构建JAR包
```bash
mvn clean package -DskipTests
```

### 2. 启动应用
```bash
java -jar target/springboot-demo-1.0.0.jar
```

### 3. 一键构建启动
```bash
./build-and-run.sh
```

## API接口

### GET /config/getMenuConfig
返回菜单配置JSON数据（带缓存）

**响应示例:**
```json
{
  "status": "success",
  "timestamp": 1632825600000,
  "menus": [
    {"id": "home", "name": "首页", "path": "/home"},
    {"id": "user", "name": "用户管理", "path": "/user"},
    {"id": "system", "name": "系统设置", "path": "/system"}
  ]
}
```

## JMeter压测

### 1. 在压测EC2上安装JMeter环境（Amazon Linux 2023）
```bash
./jmeter-setup.sh
```

### 2. 执行压测（替换为实际目标服务器IP）
```bash
./run-jmeter-test.sh <目标服务器IP>
```

### 3. 手动执行特定并发数压测
```bash
# 200并发
/opt/jmeter/bin/jmeter -n -t test-plan.jmx -l results-200.jtl -e -o report-200 -Jusers=200 -Jhost=<目标IP>

# 300并发  
/opt/jmeter/bin/jmeter -n -t test-plan.jmx -l results-300.jtl -e -o report-300 -Jusers=300 -Jhost=<目标IP>
```

## 压测结果查看

- **HTML报告**: `report-200/index.html` 和 `report-300/index.html`
- **关键指标**: TPS、成功率、响应时间
- **命令行快速查看**: 脚本会自动显示统计结果

## 注意事项

1. 确保目标服务器8080端口开放
2. JMeter服务器需要足够的网络带宽和CPU资源
3. 建议在不同可用区的EC2间进行压测以模拟真实网络环境
