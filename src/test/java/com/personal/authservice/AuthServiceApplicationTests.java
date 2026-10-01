package com.personal.authservice;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(TestcontainersConfiguration.class)
class AuthServiceApplicationTests {

    private static final String PASSWORD = "s3cret-password";

    @Autowired
    private MockMvc mockMvc;

    @Test
    void registerLoginAndAccessProtectedEndpoint() throws Exception {
        String email = uniqueEmail();

        register(email, PASSWORD)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.expiresIn").value(900))
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty());

        // Email is normalised, so login is case-insensitive
        String accessToken = token(login(email.toUpperCase(), PASSWORD).andExpect(status().isOk()), "accessToken");

        mockMvc.perform(get("/api/users/me").header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value(email))
                .andExpect(jsonPath("$.role").value("ROLE_USER"));
    }

    @Test
    void registerRejectsDuplicateEmailIgnoringCase() throws Exception {
        String email = uniqueEmail();
        register(email, PASSWORD).andExpect(status().isCreated());

        register(email.toUpperCase(), PASSWORD)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409));
    }

    @Test
    void registerValidatesInput() throws Exception {
        register("not-an-email", "short")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value(org.hamcrest.Matchers.containsString("email:")))
                .andExpect(jsonPath("$.detail").value(org.hamcrest.Matchers.containsString("password:")));
    }

    @Test
    void loginWithWrongPasswordOrUnknownEmailReturns401() throws Exception {
        String email = uniqueEmail();
        register(email, PASSWORD).andExpect(status().isCreated());

        login(email, "wrong-password")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Invalid email or password"));
        login(uniqueEmail(), PASSWORD)
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Invalid email or password"));
    }

    @Test
    void refreshIssuesNewTokensOnlyForRefreshTokens() throws Exception {
        String email = uniqueEmail();
        ResultActions registered = register(email, PASSWORD).andExpect(status().isCreated());
        String accessToken = token(registered, "accessToken");
        String refreshToken = token(registered, "refreshToken");

        refresh(refreshToken)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty());

        // An access token must not be usable as a refresh token...
        refresh(accessToken)
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Invalid or expired refresh token"));
        refresh("garbage").andExpect(status().isUnauthorized());

        // ...and a refresh token must not authenticate API calls
        mockMvc.perform(get("/api/users/me").header("Authorization", "Bearer " + refreshToken))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void protectedEndpointWithoutTokenReturns401ProblemDetail() throws Exception {
        mockMvc.perform(get("/api/users/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Authentication is required"));
    }

    @Test
    void healthProbesArePublic() throws Exception {
        mockMvc.perform(get("/actuator/health/liveness")).andExpect(status().isOk());
        mockMvc.perform(get("/actuator/health/readiness")).andExpect(status().isOk());
    }

    private ResultActions register(String email, String password) throws Exception {
        return postJson("/api/auth/register", credentials(email, password));
    }

    private ResultActions login(String email, String password) throws Exception {
        return postJson("/api/auth/login", credentials(email, password));
    }

    private ResultActions refresh(String refreshToken) throws Exception {
        return postJson("/api/auth/refresh", "{\"refreshToken\":\"%s\"}".formatted(refreshToken));
    }

    private ResultActions postJson(String path, String body) throws Exception {
        return mockMvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private static String credentials(String email, String password) {
        return "{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, password);
    }

    private static String token(ResultActions result, String field) throws Exception {
        return JsonPath.read(result.andReturn().getResponse().getContentAsString(), "$." + field);
    }

    private static String uniqueEmail() {
        return "user-" + UUID.randomUUID() + "@example.com";
    }
}
