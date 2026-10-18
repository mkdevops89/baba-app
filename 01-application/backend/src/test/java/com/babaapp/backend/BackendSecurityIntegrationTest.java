package com.babaapp.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.junit.jupiter.api.Assertions.assertNotNull;

/**
 * Exercises the complete Spring Boot MVC application context.
 *
 * These tests intentionally use the real SecurityFilterChain, controller
 * mappings, H2 database, seed data, JSON conversion, and CORS configuration.
 * This catches integration failures that isolated controller mocks would miss.
 */
@SpringBootTest(
        properties = {
                // Avoid binding the test management context to the normal
                // development management port.
                "management.server.port=0"
        }
)
@AutoConfigureMockMvc
class BackendSecurityIntegrationTest {

    private static final String APPROVED_ORIGIN = "http://localhost:3000";
    private static final String UNAPPROVED_ORIGIN = "https://untrusted.example";

    @Autowired
    private MockMvc mockMvc;

    /**
     * Proves that the Spring Boot 4 application, database schema, repositories,
     * security configuration, and seed data can initialize together.
     */
    @Test
    void applicationContextStarts() {
        // MockMvc is created only after the complete application and security
        // configuration successfully initializes.
        assertNotNull(mockMvc);
    }

    /**
     * Product browsing is an explicitly public Baba App capability.
     * The response also proves that data.sql initialized the H2 test database.
     */
    @Test
    void publicProductCatalogReturnsSeededData() throws Exception {
        mockMvc.perform(get("/api/products"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(12));
    }

    /**
     * Anonymous carts require a session identifier so one visitor cannot
     * accidentally retrieve an undefined or shared cart.
     */
    @Test
    void anonymousCartWithoutSessionIdIsRejected() throws Exception {
        mockMvc.perform(get("/api/cart"))
                .andExpect(status().isBadRequest());
    }

    /**
     * Invalid state-changing input must fail before repository modification.
     */
    @Test
    void invalidCartMutationIsRejected() throws Exception {
        mockMvc.perform(
                        post("/api/cart/add")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "productId": null,
                                          "quantity": 0,
                                          "sessionId": null
                                        }
                                        """)
                )
                .andExpect(status().isBadRequest());
    }

    /**
     * Routes outside the explicitly permitted demo endpoints must remain
     * inaccessible to anonymous callers.
     */
    @Test
    void anonymousRequestToProtectedRouteIsForbidden() throws Exception {
        mockMvc.perform(get("/internal/security-check"))
                .andExpect(status().isForbidden());
    }

    /**
     * Browser preflight requests from the configured frontend are allowed and
     * may include credentials.
     */
    @Test
    void approvedCorsOriginIsAllowed() throws Exception {
        mockMvc.perform(
                        options("/api/products")
                                .header(HttpHeaders.ORIGIN, APPROVED_ORIGIN)
                                .header(
                                        HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD,
                                        "GET"
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        header().string(
                                HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN,
                                APPROVED_ORIGIN
                        )
                )
                .andExpect(
                        header().string(
                                HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS,
                                "true"
                        )
                );
    }

    /**
     * Origins not present in the allowlist must fail the browser preflight
     * check rather than receiving cross-origin access.
     */
    @Test
    void unapprovedCorsOriginIsRejected() throws Exception {
        mockMvc.perform(
                        options("/api/products")
                                .header(HttpHeaders.ORIGIN, UNAPPROVED_ORIGIN)
                                .header(
                                        HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD,
                                        "GET"
                                )
                )
                .andExpect(status().isForbidden());
    }
}
