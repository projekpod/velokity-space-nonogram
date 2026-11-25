extends RefCounted

const PRODUCTS := {
	&"no_ads": "IAP_NO_ADS",
	&"coins_500": "IAP_COINS_500",
	&"coins_2000": "IAP_COINS_2000",
}


func is_product_available(_product: StringName) -> bool:
	return false


func request_purchase(_product: StringName) -> bool:
	return false
