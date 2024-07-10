package com.example.demo.orderdata;

import java.math.BigDecimal;
import java.util.Date;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.ToString;
/*
 * Aiven connector does not work properly with avro, so decimal values are wrong
 * https://github.com/Aiven-Open/http-connector-for-apache-kafka/issues/214
 */
@ToString
public class OrderData {

//	@JsonProperty("ORDERID")
//	private Long orderId;
	
	@JsonProperty("ORDERDATE")
	private Date orderDate;
	
//	@JsonProperty("CUSTOMERID")
//	private Integer customerId;
	
	@JsonProperty("AMOUNT")
	private BigDecimal amount;

//	public Long getOrderId() {
//		return orderId;
//	}
//
//	public void setOrderId(Long orderId) {
//		this.orderId = orderId;
//	}

	public Date getOrderDate() {
		return orderDate;
	}

	public void setOrderDate(Date orderDate) {
		this.orderDate = orderDate;
	}

//	public Integer getCustomerId() {
//		return customerId;
//	}
//
//	public void setCustomerId(Integer customerId) {
//		this.customerId = customerId;
//	}

	public BigDecimal getAmount() {
		return amount;
	}

	public void setAmount(BigDecimal amount) {
		this.amount = amount;
	}
	
	
	
	
}
