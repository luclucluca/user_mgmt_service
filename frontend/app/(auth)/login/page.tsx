"use client"

import {useRouter} from "next/navigation";
import {LoginForm} from "@/components/auth/forms/login-form";
import {LoginFormValues} from "@/schemas/login-schema";

export default function LoginPage() {
    const router = useRouter();

    const handleLogin = async (data:LoginFormValues) => {
        const res = await fetch("/api/login", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify(data),
        })

        if (!res.ok) {
            throw new Error("Login failed")
        }

        // optional redirect
        window.location.href = "/dashboard"
    }

    return (
        <LoginForm
            onSubmit={handleLogin}
            onSignup={() => router.push("/signup")}
        />
    )
}