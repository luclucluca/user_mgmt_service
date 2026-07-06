import { useState } from "react"
import { EyeIcon, EyeOffIcon } from "lucide-react"
import { Input } from "@/components/ui/input"
import {
    Field,
    FieldLabel,
    FieldDescription,
    FieldError,
} from "@/components/ui/field"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import { LockIcon } from "lucide-react"
import { Progress } from "@/components/ui/progress"
import { calculatePasswordStrength, getStrengthLabel } from "@/lib/password"
import { useMemo } from "react"

interface PasswordStrengthIndicatorProps {
    feedback: string[];
    score: number;
}

function PasswordStrengthIndicator({
    feedback,
    score,
}: PasswordStrengthIndicatorProps) {
    return (
        <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between gap-2">
                <Progress
                    aria-label={`Password strength: ${getStrengthLabel(score)}`}
                    className="h-1.5"
                    value={(score / 5) * 100}
                />
                <span
                    className={cn(
                        "font-medium text-xs",
                        score <= 1 && "text-destructive",
                        score === 2 && "text-amber-600",
                        score === 3 && "text-yellow-600",
                        score === 4 && "text-lime-600",
                        score >= 5 && "text-green-600"
                    )}
                >
                    {getStrengthLabel(score)}
                </span>
            </div>
            {feedback.length > 0 && (
                <FieldDescription>
                    <span className="text-xs">Missing: {feedback.join(", ")}</span>
                </FieldDescription>
            )}
        </div>
    );
}

type PasswordFieldProps = React.ComponentProps<"input"> & {
    label?: string
    error?: { message?: string }
    showForgot?: boolean
    onForgot?: () => void
    showStrength?: boolean
}

export function PasswordField({
    label,
    error,
    showForgot,
    onForgot,
    showStrength,
    className,
    value,
    ...props
}: PasswordFieldProps) {
    const [showPassword, setShowPassword] = useState(false)
    const passwordValue = String(value ?? "")

    const passwordStrength = useMemo(() => {
        return calculatePasswordStrength(passwordValue)
    }, [passwordValue])

    return (
        <Field>
            <div className="flex items-center">
                <FieldLabel htmlFor="password">{label}</FieldLabel>
                {showForgot && onForgot && (
                    <a
                        href="#"
                        className="ml-auto text-sm underline-offset-4 hover:underline"
                        onClick={(e) => {
                            e.preventDefault()
                            onForgot()
                        }}
                    >
                        Forgot your password?
                    </a>
                )}
            </div>
            <div className='relative'>
                <LockIcon className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                    id="password"
                    type={showPassword ? "text" : "password"}
                    className={cn("bg-background px-10", className)}
                    {...props}
                />
                <Button
                    type="button"
                    variant='ghost'
                    size='icon'
                    onClick={() => setShowPassword(prevState => !prevState)}
                    className='text-muted-foreground focus-visible:ring-ring/50 absolute inset-y-0 right-1 flex items-center rounded-l-none hover:bg-transparent'
                >
                    {showPassword ? <EyeOffIcon /> : <EyeIcon />}
                    <span className='sr-only'>{showPassword ? 'Hide password' : 'Show password'}</span>
                </Button>
            </div>
            {error && <FieldError>{error.message}</FieldError>}
            {showStrength && passwordValue && (
                <PasswordStrengthIndicator
                    feedback={passwordStrength.feedback}
                    score={passwordStrength.score}
                />
            )}
        </Field>
    )
}