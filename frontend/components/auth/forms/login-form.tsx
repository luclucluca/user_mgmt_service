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
import {LoginFormValues, loginSchema} from "@/schemas/login-schema";

type LoginFormProps = {
  onSubmit: (data: LoginFormValues) => Promise<void>
  onSignup: () => void
  className?: string
}

export function LoginForm({
  onSubmit,
  onSignup,
  className,
  ...props
}: LoginFormProps) {
  const {
    control,
    handleSubmit,
    register,
    reset,
    formState: { errors, isValid, isSubmitting }
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema)
  })

  return (
    <form
      className={cn("flex flex-col gap-6", className)}
      onSubmit={handleSubmit((data) => {
        onSubmit(data)
        reset()
      })}
      {...props}>
      <FieldGroup>
        <div className="flex flex-col items-center gap-1 text-center">
          <h1 className="text-2xl font-bold">Welcome Back</h1>
          <p className="text-sm text-balance text-muted-foreground">
            Enter your credentials to login to your account
          </p>
        </div>
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
              showForgot={false}
              error={fieldState.error}
              {...field}
            />
          )}
        />
        <Button
          type="submit"
          disabled={!isValid || isSubmitting}
        >
          {isSubmitting ? "Logging in ..." : "Login"}
        </Button>
          <FieldDescription className="text-center">
            Don&apos;t have an account?{" "}
            <a
              href="#"
              onClick={(e) => {
                e.preventDefault()
                onSignup()
              }}
              className="underline underline-offset-4"
            >
              Sign up
            </a>
          </FieldDescription>
      </FieldGroup>
    </form>
  )
}
