class_name ShopOffer
extends RefCounted
var offer_id: StringName
var shop_id: StringName = &"demo_shop"
var item: ItemDefinition
var price := 0
var stock := 0
var quote_version := 1
var run_epoch := 0
var stage_epoch := 0
var currency_type: StringName = &"RunCoin"

func copy() -> ShopOffer:
	var result := ShopOffer.new()
	result.offer_id = offer_id
	result.shop_id = shop_id
	result.item = item.duplicate(true)
	result.price = price
	result.stock = stock
	result.quote_version = quote_version
	result.run_epoch = run_epoch
	result.stage_epoch = stage_epoch
	result.currency_type = currency_type
	return result
