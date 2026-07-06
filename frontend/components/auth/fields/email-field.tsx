import { Input } from "@/components/ui/input"
import {
    Field,
    FieldLabel,
    FieldError,
} from "@/components/ui/field"
import { cn } from "@/lib/utils"
import { MailIcon } from "lucide-react"

type EmailFieldProps = React.ComponentProps<"input"> & {
    error?: { message?: string }
}

export function EmailField({
    error,
    className,
    ...props
}: EmailFieldProps) {
    return (
        <Field>
            <FieldLabel htmlFor="email">Email</FieldLabel>
            <div className="relative">
                <MailIcon className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                    id="email"
                    placeholder="john.doe@example.com"
                    className={cn("bg-background pl-10", className)}
                    {...props}
                />
            </div>
            {error && (
                <FieldError>{error.message}</FieldError>
            )}
        </Field>
    )
}
