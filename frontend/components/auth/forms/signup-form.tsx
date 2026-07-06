import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import {
  FieldDescription,
  FieldGroup,
} from "@/components/ui/field"
import { zodResolver } from "@hookform/resolvers/zod"
import { useForm, Controller } from "react-hook-form"
import { PasswordField } from "../fields/password-field"
import { EmailField } from "../fields/email-field"
import { NameField } from "../fields/name-field"
import { SignupFormValues, signupSchema } from "@/schemas/signup-schema";

type SignupFormProps = {
  onSubmit: (data: SignupFormValues) => Promise<void>
  onCreate: () => void
  className?: string
}

export function SignupForm({
  onSubmit,
  onCreate,
  className,
  ...props
}: SignupFormProps) {
  const {
    control,
    handleSubmit,
    register,
    reset,
    formState: { errors, isValid, isSubmitting }
  } = useForm<SignupFormValues>({
    resolver: zodResolver(signupSchema),
    mode: "onChange"
  })

  return (
    <form
      className={cn("flex flex-col gap-6", className)}
      onSubmit={handleSubmit(async (data) => {
        await onSubmit(data)
        reset()
      })}
      {...props}>
      <FieldGroup>
        <div className="flex flex-col items-center gap-1 text-center">
          <h1 className="text-2xl font-bold">Get Started</h1>
          <p className="text-sm text-balance text-muted-foreground">
            Fill in the form to create your account
          </p>
        </div>
        <NameField
          id="firstName"
          label="First Name"
          placeholder="John"
          error={errors.firstName}
          {...register("firstName")}
        />
        <NameField
          id="lastName"
          label="Last Name"
          placeholder="Doe"
          error={errors.lastName}
          {...register("lastName")}
        />
        <EmailField
          error={errors.email}
          {...register("email")}
        />
        <Controller
          name="password"
          control={control}
          render={({ field, fieldState }) => (
            <PasswordField
              label="Password"
              showStrength={true}
              error={fieldState.error}
              {...field}
            />
          )}
        />
        <Controller
          name="confirmPassword"
          control={control}
          render={({ field, fieldState }) => (
            <PasswordField
              label="Confirm Password"
              error={fieldState.error}
              {...field}
            />
          )}
        />
        <Button
          type="submit"
          disabled={!isValid || isSubmitting}
        >
          {isSubmitting ? "Creating account ..." : "Create Account"}
        </Button>
          <FieldDescription className="px-6 text-center">
            Already have an account?{" "}
            <a
              href="#"
              onClick={(e) => {
                e.preventDefault()
                onCreate()
              }}
              className="underline underline-offset-4"
            >
              Sign in
            </a>
          </FieldDescription>
      </FieldGroup>
    </form >
  )
}
