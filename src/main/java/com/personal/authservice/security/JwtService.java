package com.personal.authservice.security;

import com.personal.authservice.config.JwtProperties;
import com.personal.authservice.entity.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.JwtParser;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

@Service
public class JwtService {

    static final String CLAIM_TOKEN_TYPE = "token_type";
    static final String CLAIM_USER_ID = "uid";
    static final String CLAIM_ROLE = "role";

    public enum TokenType { ACCESS, REFRESH }

    private final JwtProperties properties;
    private final SecretKey signingKey;
    private final JwtParser parser;

    public JwtService(JwtProperties properties) {
        this.properties = properties;
        this.signingKey = Keys.hmacShaKeyFor(properties.secret().getBytes(StandardCharsets.UTF_8));
        this.parser = Jwts.parser()
                .verifyWith(signingKey)
                .requireIssuer(properties.issuer())
                .build();
    }

    public String generateAccessToken(User user) {
        return buildToken(user, TokenType.ACCESS, properties.accessTokenTtl());
    }

    public String generateRefreshToken(User user) {
        return buildToken(user, TokenType.REFRESH, properties.refreshTokenTtl());
    }

    public Duration accessTokenTtl() {
        return properties.accessTokenTtl();
    }

    private String buildToken(User user, TokenType type, Duration ttl) {
        Instant now = Instant.now();
        var builder = Jwts.builder()
                .id(UUID.randomUUID().toString())
                .issuer(properties.issuer())
                .subject(user.getEmail())
                .claim(CLAIM_TOKEN_TYPE, type.name())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(ttl)));
        if (type == TokenType.ACCESS) {
            builder.claim(CLAIM_USER_ID, user.getId())
                    .claim(CLAIM_ROLE, user.getRole().name());
        }
        return builder.signWith(signingKey).compact();
    }

    /**
     * Verifies signature, expiry, issuer and token type in a single parse.
     *
     * @return the subject (user email)
     * @throws JwtException if the token is invalid, expired or of the wrong type
     */
    public String validateAndGetSubject(String token, TokenType expectedType) {
        Claims claims = parser.parseSignedClaims(token).getPayload();
        if (!expectedType.name().equals(claims.get(CLAIM_TOKEN_TYPE, String.class))) {
            throw new JwtException("Expected a " + expectedType + " token");
        }
        return claims.getSubject();
    }
}
