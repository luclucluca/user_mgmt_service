export const passwordRules = [
    {
        test: (v: string) => v.length >= 8,
        message: "8+ characters",
    },
    {
        test: (v: string) => /[a-z]/.test(v),
        message: "lowercase",
    },
    {
        test: (v: string) => /[A-Z]/.test(v),
        message: "uppercase",
    },
    {
        test: (v: string) => /\d/.test(v),
        message: "number",
    },
    {
        test: (v: string) => /[^a-zA-Z\d]/.test(v),
        message: "special character",
    },
]

export function calculatePasswordStrength(password: string) {
    let score = 0
    const feedback: string[] = []

    for (const rule of passwordRules) {
        if (rule.test(password)) score++
        else feedback.push(rule.message)
    }

    return { score, feedback }
}

export function getStrengthLabel(score: number) {
    if (score <= 1) return "Weak"
    if (score <= 2) return "Fair"
    if (score <= 3) return "Good"
    if (score <= 4) return "Strong"
    return "Optimal"
}