/** @type {import('tailwindcss').Config} */
module.exports = {
    content: [
        "./src/**/*.jl"
    ],
    darkMode: 'class',
    theme: {
        extend: {
            fontFamily: {
                sans: ['Optima', 'Palatino Linotype', 'Book Antiqua', 'EB Garamond', 'serif'],
                serif: ['EB Garamond', 'Palatino Linotype', 'Book Antiqua', 'Georgia', 'serif'],
            }
        }
    },
    plugins: [],
}
