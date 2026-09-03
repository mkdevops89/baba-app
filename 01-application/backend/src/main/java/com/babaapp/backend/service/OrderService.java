package com.babaapp.backend.service;

import com.babaapp.backend.model.Order;
import com.babaapp.backend.repository.OrderRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;

@Service
public class OrderService {

    @Autowired
    private OrderRepository orderRepository;

    public Order placeOrder(String username, BigDecimal amount) {
        // 1. Save initial order state to MySQL
        Order order = new Order(username, amount, "PENDING");
        return orderRepository.save(order);

    }
}
