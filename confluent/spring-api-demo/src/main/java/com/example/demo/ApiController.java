package com.example.demo;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.example.demo.orderdata.OrderData;

import lombok.extern.slf4j.Slf4j;

@RestController
@Slf4j
@RequestMapping("/api")
public class ApiController {
	
	

	@PostMapping(value = "/orderData")
	@ResponseStatus(code = HttpStatus.NO_CONTENT)
	public void createOrderData(@RequestBody OrderData orderData) {
		log.info("Create order with data {}",  orderData);
		
	}
}
