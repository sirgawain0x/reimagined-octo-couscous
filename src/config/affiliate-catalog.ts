const shops = [
  { name: "Amazon", hosts: ["amzn.to", "amazon.com", "www.amazon.com"], defaultUrl: "https://amzn.to/3KG7zfG" },
  { name: "Walmart", hosts: ["goto.walmart.com", "www.walmart.com", "walmart.com"], defaultUrl: "https://goto.walmart.com/c/5898735/1398372/16662?sourceid=imp_000011112222333344&veh=aff&u=https%3A%2F%2Fwww.walmart.com" },
  { name: "eBay", hosts: ["ebay.us", "www.ebay.com", "ebay.com"], defaultUrl: "https://ebay.us/XS4KJV" },
] as const

export function affiliateCatalog(overrides: Partial<Record<"Amazon" | "Walmart" | "eBay", string>>) {
  return shops.map(({ name, hosts, defaultUrl }) => {
    const url = new URL(overrides[name] || defaultUrl)
    if (url.protocol !== "https:" || url.port || url.username || url.password ||
        !hosts.some(host => host === url.hostname)) {
      throw new Error(`Invalid affiliate destination for ${name}`)
    }
    return { name, url: url.href }
  })
}
