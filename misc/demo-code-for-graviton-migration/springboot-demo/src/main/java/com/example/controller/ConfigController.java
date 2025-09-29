package com.example.controller;

import com.example.service.ConfigService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class ConfigController {

    @Autowired
    private ConfigService configService;

    @GetMapping("/config/getMenuConfig")
    public Map<String, Object> getMenuConfig() {
        return configService.getMenuConfig();
    }
}
