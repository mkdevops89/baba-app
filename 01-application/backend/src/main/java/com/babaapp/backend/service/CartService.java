package com.babaapp.backend.service;

import com.babaapp.backend.model.CartItem;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class CartService {

    private static final String CART_PREFIX = "cart:";

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    public void addToCart(String username, CartItem item) {
        String key = CART_PREFIX + username;
        redisTemplate.opsForList().rightPush(key, item);
    }

    public List<CartItem> getCart(String username) {
        String key = CART_PREFIX + username;
        List<Object> objects = redisTemplate.opsForList().range(key, 0, -1);
        if (objects == null)
            return List.of();

        return objects.stream()
                .map(obj -> (CartItem) obj)
                .collect(Collectors.toList());
    }

    public void clearCart(String username) {
        String key = CART_PREFIX + username;
        redisTemplate.delete(key);
    }
}
