import * as z from "zod"
import {passwordRules} from "./password"

export const firstNameSchema = z
    .string()
    .min(1, "")
    .max(25, "That's a bit long for a first name")
    .regex(/^[\p{L} '-]+$/u, "There are characters that we don't support")
    .transform((v) => v.trim().toLowerCase())


export const lastNameSchema = z
    .string()
    .min(1, "")
    .max(25, "That's a bit long for a last name")
    .regex(/^[\p{L} '-]+$/u, "There are characters that we don't support")
    .transform((v) => v.trim().toLowerCase())


export const emailSchema = z
    .string()
    .min(1, "")
    .max(50, "That's a bit long for an email")
    .email("")
    .transform((v) => v.trim().toLowerCase())


export const passwordSchema = z
    .string()
    .min(1, "")
    .refine((v) => passwordRules.every((r) => r.test(v)), {
        message: "",
    })

export const confirmPasswordSchema = z
    .string()
    .min(1, "")

export const verificationCodeSchema = z
    .string()
    .length(6, "")
    .transform((v) => v.trim())

export const numericVerificationCodeSchema = z
    .string()
    .regex(/^\d+$/, "Only numbers allowed")
    .length(6, "")
    .transform((v) => v.trim())


export const recoveryCodeSchema = z
    .string()
    .min(1, "")
    .max(25, "That's a bit long for a recovery code")
    .transform((v) => v.trim())

