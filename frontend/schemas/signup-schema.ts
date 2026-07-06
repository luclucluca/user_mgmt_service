import * as z from "zod"
import {
  firstNameSchema,
  lastNameSchema,
  emailSchema,
  passwordSchema,
  confirmPasswordSchema,
} from "@/lib/validation"

export const signupSchema = z
.object({
  firstName: firstNameSchema,
  lastName: lastNameSchema,
  email: emailSchema,
  password: passwordSchema,
  confirmPassword: confirmPasswordSchema,
})
.refine((data) => data.password === data.confirmPassword, {
  message: "Passwords do not match",
  path: ["confirmPassword"],
})

export type SignupFormValues = z.infer<typeof signupSchema>