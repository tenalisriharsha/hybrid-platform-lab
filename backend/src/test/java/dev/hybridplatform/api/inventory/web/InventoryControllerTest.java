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
import org.springframework.test.annotation.DirtiesContext;
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
    void summaryEndpointReturnsInventoryRollup() throws Exception {
        mockMvc.perform(get("/api/v1/summary"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hostCount").value(2))
                .andExpect(jsonPath("$.vmCount").value(3))
                .andExpect(jsonPath("$.datastoreCount").value(2))
                .andExpect(jsonPath("$.vmsPoweredOn").value(2))
                .andExpect(jsonPath("$.vmsPoweredOff").value(1))
                .andExpect(jsonPath("$.totalDatastoreCapacityGb").value(6144))
                .andExpect(jsonPath("$.totalDatastoreFreeGb").value(4300));
    }

    @Test
    void infoEndpointReturnsPlatformMetadata() throws Exception {
        mockMvc.perform(get("/api/v1/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("platform-api"))
                .andExpect(jsonPath("$.phase").value("2"));
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

    @Test
    @DirtiesContext(methodMode = DirtiesContext.MethodMode.AFTER_METHOD)
    void syncReplacesInventoryAndSubsequentReadsReflectIt() throws Exception {
        String payload = """
                {
                  "hosts": [
                    {"id": "host-synced", "name": "esx-synced", "cluster": "synced-cluster",
                     "cpuCores": 16, "memoryMb": 65536, "datastoreIds": ["ds-synced"]}
                  ],
                  "vms": [
                    {"id": "vm-synced", "name": "synced-vm", "hostId": "host-synced",
                     "powerState": "POWERED_ON", "cpuCount": 4, "memoryMb": 8192}
                  ],
                  "datastores": [
                    {"id": "ds-synced", "name": "synced-ds", "capacityGb": 2048, "freeGb": 1024}
                  ]
                }
                """;

        mockMvc.perform(post("/api/v1/sync").contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hostCount").value(1))
                .andExpect(jsonPath("$.vmCount").value(1))
                .andExpect(jsonPath("$.datastoreCount").value(1))
                .andExpect(jsonPath("$.syncedAt").exists());

        mockMvc.perform(get("/api/v1/hosts"))
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id").value("host-synced"));
        mockMvc.perform(get("/api/v1/vms/vm-synced"))
                .andExpect(jsonPath("$.hostId").value("host-synced"));
        mockMvc.perform(get("/api/v1/hosts/host-1")).andExpect(status().isNotFound());
    }

    @Test
    void syncRejectsVmReferencingUnknownHost() throws Exception {
        String payload = """
                {
                  "hosts": [],
                  "vms": [
                    {"id": "vm-orphan", "name": "orphan", "hostId": "host-missing",
                     "powerState": "POWERED_ON", "cpuCount": 1, "memoryMb": 1024}
                  ],
                  "datastores": []
                }
                """;

        mockMvc.perform(post("/api/v1/sync").contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Synced VM 'vm-orphan' references unknown host 'host-missing'"));
    }
}
