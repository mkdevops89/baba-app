package com.babaapp.backend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Value("${babaapp.cors.allowed-origin:http://localhost:3000}")
    private String allowedOrigin;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/api/auth/**", "/api/products/**", "/products/**", "/api/cart/**",
                                "/api/orders/**",
                                "/actuator/health", "/actuator/prometheus")
                        .permitAll() // Phase 01 demo endpoints
                        .anyRequest().authenticated());
        return http.build();
    }

    /**
     * Defines an intentionally empty local user store.
     *
     * Security rationale:
     * Spring Boot creates a default development user when no authentication
     * provider or UserDetailsService is configured. That behavior generates
     * a temporary password and writes it to application logs, which can then
     * be collected by centralized logging systems such as Loki.
     *
     * Baba App does not use local Spring users at this stage. Providing an
     * empty UserDetailsService disables the default generated credential
     * while preserving authentication requirements for protected endpoints.
     * A production identity provider will replace this mechanism in the
     * identity phase.
     */
    @Bean
    public UserDetailsService userDetailsService() {
        return new InMemoryUserDetailsManager();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(List.of(allowedOrigin));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("*"));
        configuration.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
