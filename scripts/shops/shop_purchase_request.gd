class_name ShopPurchaseRequest
extends RefCounted
var token: DemoToken
var shop_id: StringName = &"demo_shop"
var offer_id: StringName
# MVP items are one-per-transaction; arbitrary quantities remain explicitly rejected.
var quantity := 1
var quote_version := 1
var transaction_id: StringName
