package dev.hybridplatform.api.inventory.web;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.actuate.observability.AutoConfigureObservability;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@AutoConfigureObservability
class InventoryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void listHostsReturnsSeededHosts() throws Exception {
        mockMvc.perform(get("/api/v1/hosts"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].id").exists());
    }

    @Test
    void getHostReturnsNotFoundForUnknownId() throws Exception {
        mockMvc.perform(get("/api/v1/hosts/does-not-exist"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("Host not found: does-not-exist"));
    }

    @Test
    void getHostReturnsSeededHost() throws Exception {
        mockMvc.perform(get("/api/v1/hosts/host-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("esx-lab-01"));
    }

    @Test
    void listVmsReturnsSeededVms() throws Exception {
        mockMvc.perform(get("/api/v1/vms"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(3)));
    }

    @Test
    void getVmReturnsNotFoundForUnknownId() throws Exception {
        mockMvc.perform(get("/api/v1/vms/does-not-exist"))
                .andExpect(status().isNotFound());
    }

    @Test
    void setVmPowerUpdatesState() throws Exception {
        mockMvc.perform(post("/api/v1/vms/vm-3/power")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"state\":\"POWERED_ON\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.powerState").value("POWERED_ON"));

        mockMvc.perform(get("/api/v1/vms/vm-3"))
                .andExpect(jsonPath("$.powerState").value("POWERED_ON"));
    }

    @Test
    void setVmPowerReturnsNotFoundForUnknownVm() throws Exception {
        mockMvc.perform(post("/api/v1/vms/does-not-exist/power")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"state\":\"POWERED_ON\"}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void listDatastoresReturnsSeededDatastores() throws Exception {
        mockMvc.perform(get("/api/v1/datastores"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)));
    }

    @Test
    void getDatastoreReturnsNotFoundForUnknownId() throws Exception {
        mockMvc.perform(get("/api/v1/datastores/does-not-exist"))
                .andExpect(status().isNotFound());
    }

    @Test
    void infoEndpointReturnsPlatformMetadata() throws Exception {
        mockMvc.perform(get("/api/v1/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("platform-api"))
                .andExpect(jsonPath("$.phase").value("1"));
    }

    @Test
    void actuatorHealthIsUp() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void actuatorPrometheusExposesMetrics() throws Exception {
        mockMvc.perform(get("/actuator/prometheus"))
                .andExpect(status().isOk());
    }
}
