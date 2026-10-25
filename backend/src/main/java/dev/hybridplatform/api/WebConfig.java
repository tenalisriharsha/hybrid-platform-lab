package dev.hybridplatform.api;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Allows the Angular dashboard (served from its own origin, e.g. the Angular
 * dev server or an nginx container) to call this API's REST endpoints
 * cross-origin. This is a lab, so any origin is allowed rather than pinning
 * to a specific dashboard host/port.
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**").allowedOriginPatterns("*").allowedMethods("GET", "POST");
    }
}
