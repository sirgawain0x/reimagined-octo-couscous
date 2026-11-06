import { affiliateCatalog } from "./affiliate-catalog"

export const storefront = affiliateCatalog({
  Amazon: import.meta.env.VITE_AMAZON_AFFILIATE_LINK,
  Walmart: import.meta.env.VITE_WALMART_AFFILIATE_LINK,
  eBay: import.meta.env.VITE_EBAY_AFFILIATE_LINK,
})
