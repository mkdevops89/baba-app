package com.babaapp.backend.controller;

import com.babaapp.backend.model.Order;
import com.babaapp.backend.service.OrderService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @Autowired
    private OrderService orderService;

    @PostMapping("/{username}")
    public Order placeOrder(@PathVariable String username, @RequestParam BigDecimal amount) {
        return orderService.placeOrder(username, amount);
    }
}
