package com.example.service;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;
import java.util.Arrays;

@Service
public class ConfigService {

    @Cacheable("menuConfig")
    public Map<String, Object> getMenuConfig() {
        Map<String, Object> config = new HashMap<>();
        config.put("status", "success");
        config.put("timestamp", System.currentTimeMillis());
        config.put("menus", Arrays.asList(
            createMenu("home", "首页", "/home"),
            createMenu("user", "用户管理", "/user"),
            createMenu("system", "系统设置", "/system")
        ));
        return config;
    }

    private Map<String, Object> createMenu(String id, String name, String path) {
        Map<String, Object> menu = new HashMap<>();
        menu.put("id", id);
        menu.put("name", name);
        menu.put("path", path);
        return menu;
    }
}
