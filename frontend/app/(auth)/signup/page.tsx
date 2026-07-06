"use client"

import {useRouter} from "next/navigation";
import {UserRegisterDTO} from "@/models/user";
import {SignupFormValues} from "@/schemas/signup-schema";
import {SignupForm} from "@/components/auth/forms/signup-form";

export default function SignupPage() {
    const router = useRouter();

    const handleSignup = async (data: SignupFormValues) => {
        const api_url = process.env.NEXT_PUBLIC_API_URL + "/users/register";
        const userRegisterDTO : UserRegisterDTO = (({ confirmPassword, ...dto }) => dto)(data);
        const response = await fetch(api_url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify(userRegisterDTO),
        })

        if (!response.ok) {
            throw new Error("Registration failed")
        }

        router.push("/login")
    }

    return (
        <SignupForm
            onSubmit={handleSignup}
            onCreate={() => router.push("/login")}
        />
    )
}