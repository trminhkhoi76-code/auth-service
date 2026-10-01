package com.personal.authservice.service;

import com.personal.authservice.dto.AuthResponse;
import com.personal.authservice.dto.LoginRequest;
import com.personal.authservice.dto.RegisterRequest;
import com.personal.authservice.dto.UserResponse;
import com.personal.authservice.entity.User;
import com.personal.authservice.exception.EmailAlreadyExistsException;
import com.personal.authservice.exception.InvalidRefreshTokenException;
import com.personal.authservice.repository.UserRepository;
import com.personal.authservice.security.JwtService;
import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = normalizeEmail(request.email());
        if (userRepository.existsByEmail(email)) {
            throw new EmailAlreadyExistsException(email);
        }

        User user = userRepository.save(User.builder()
                .email(email)
                .password(passwordEncoder.encode(request.password()))
                .build());

        return issueTokens(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        String email = normalizeEmail(request.email());
        // Throws an AuthenticationException on bad credentials / disabled account
        authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(email, request.password()));

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BadCredentialsException("Invalid email or password"));
        return issueTokens(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse refresh(String refreshToken) {
        String email;
        try {
            email = jwtService.validateAndGetSubject(refreshToken, JwtService.TokenType.REFRESH);
        } catch (JwtException | IllegalArgumentException e) {
            throw new InvalidRefreshTokenException();
        }

        User user = userRepository.findByEmail(email)
                .filter(User::isEnabled)
                .orElseThrow(InvalidRefreshTokenException::new);
        return issueTokens(user);
    }

    @Transactional(readOnly = true)
    public UserResponse getProfile(String email) {
        return userRepository.findByEmail(email)
                .map(UserResponse::from)
                .orElseThrow(() -> new UsernameNotFoundException("No user found with email: " + email));
    }

    private AuthResponse issueTokens(User user) {
        return new AuthResponse(
                jwtService.generateAccessToken(user),
                jwtService.generateRefreshToken(user),
                jwtService.accessTokenTtl().toSeconds()
        );
    }

    private static String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
