package dev.hybridplatform.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class PlatformInfoController {

    private static final PlatformInfo INFO = new PlatformInfo("platform-api", "2", "Hybrid Platform Lab control-plane API");

    @GetMapping("/info")
    public PlatformInfo info() {
        return INFO;
    }

    public record PlatformInfo(String name, String phase, String description) {
    }
}
