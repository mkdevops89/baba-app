package com.babaapp.backend.controller;

import com.babaapp.backend.model.CartItem;
import com.babaapp.backend.model.Product;
import com.babaapp.backend.model.User;
import com.babaapp.backend.repository.CartRepository;
import com.babaapp.backend.repository.ProductRepository;
import com.babaapp.backend.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/cart")
public class CartController {

    private final CartRepository cartRepository;
    private final ProductRepository productRepository;
    private final UserRepository userRepository;

    public CartController(
            CartRepository cartRepository,
            ProductRepository productRepository,
            UserRepository userRepository) {
        this.cartRepository = cartRepository;
        this.productRepository = productRepository;
        this.userRepository = userRepository;
    }

    @GetMapping
    public ResponseEntity<List<CartItem>> getCart(
            @RequestParam(value = "sessionId", required = false) String sessionId) {

        User user = getAuthenticatedUser();
        if (user != null) {
            return ResponseEntity.ok(cartRepository.findByUser(user));
        }

        if (sessionId == null || sessionId.isBlank()) {
            return ResponseEntity.badRequest().build();
        }

        return ResponseEntity.ok(cartRepository.findBySessionId(sessionId));
    }

    @PostMapping("/add")
    public ResponseEntity<String> addToCart(@RequestBody AddCartRequest request) {
        if (request.productId() == null || request.quantity() == 0) {
            return ResponseEntity.badRequest().body("productId and non-zero quantity are required");
        }

        Product product = productRepository.findById(request.productId())
                .orElseThrow(() -> new IllegalArgumentException("Product not found"));

        User user = getAuthenticatedUser();

        if (user != null) {
            updateAuthenticatedCart(user, product, request.quantity());
            return ResponseEntity.ok("Cart updated");
        }

        if (request.sessionId() == null || request.sessionId().isBlank()) {
            return ResponseEntity.badRequest().body("sessionId is required for an anonymous cart");
        }

        updateAnonymousCart(request.sessionId(), product, request.quantity());
        return ResponseEntity.ok("Cart updated");
    }

    private User getAuthenticatedUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equals(auth.getPrincipal())) {
            return null;
        }

        if (auth.getPrincipal() instanceof UserDetails userDetails) {
            return userRepository.findByUsername(userDetails.getUsername()).orElse(null);
        }

        return null;
    }

    private void updateAuthenticatedCart(User user, Product product, int quantityDelta) {
        Optional<CartItem> existing = cartRepository.findByUserAndProductId(user, product.getId());
        applyQuantityChange(existing, user, product, quantityDelta, null);
    }

    private void updateAnonymousCart(String sessionId, Product product, int quantityDelta) {
        Optional<CartItem> existing = cartRepository.findBySessionIdAndProductId(sessionId, product.getId());
        applyQuantityChange(existing, null, product, quantityDelta, sessionId);
    }

    private void applyQuantityChange(
            Optional<CartItem> existing,
            User user,
            Product product,
            int quantityDelta,
            String sessionId) {

        if (existing.isPresent()) {
            CartItem item = existing.get();
            int updatedQuantity = item.getQuantity() + quantityDelta;
            if (updatedQuantity <= 0) {
                cartRepository.delete(item);
            } else {
                item.setQuantity(updatedQuantity);
                cartRepository.save(item);
            }
            return;
        }

        if (quantityDelta > 0) {
            cartRepository.save(new CartItem(user, product, quantityDelta, sessionId));
        }
    }

    public record AddCartRequest(Long productId, int quantity, String sessionId) {
    }
}
