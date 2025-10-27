/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{svelte,js,ts}"
  ],
  theme: {
    extend: {
      fontFamily: {
        'sans': ['Figtree', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
