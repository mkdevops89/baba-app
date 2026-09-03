package com.babaapp.backend.repository;

import com.babaapp.backend.model.CartItem;
import com.babaapp.backend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CartRepository extends JpaRepository<CartItem, Long> {

    List<CartItem> findByUser(User user);

    List<CartItem> findBySessionId(String sessionId);

    Optional<CartItem> findByUserAndProductId(User user, Long productId);

    Optional<CartItem> findBySessionIdAndProductId(String sessionId, Long productId);
}
