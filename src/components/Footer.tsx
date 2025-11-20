function Footer() {
  return (
    <footer className="container mx-auto max-w-7xl px-6 lg:px-8 py-8 mt-12 border-t border-gray-700">
      <div className="text-center text-gray-500">
        <p>&copy; {new Date().getFullYear()} BitRewards. All rights reserved.</p>
        <p className="text-sm mt-2">
          Powered by the <span className="font-semibold text-blue-400">Internet Computer</span>
        </p>
      </div>
    </footer>
  )
}

export default Footer

