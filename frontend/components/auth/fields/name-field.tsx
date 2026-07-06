import { Input } from "@/components/ui/input"
import {
    Field,
    FieldLabel,
    FieldError,
} from "@/components/ui/field"
import { cn } from "@/lib/utils"
import { UserIcon } from "lucide-react"

type NameFieldProps = React.ComponentProps<"input"> & {
    id: string
    label: string
    error?: { message?: string }
}

export function NameField({
    id,
    label,
    placeholder,
    error,
    className,
    ...props
}: NameFieldProps) {
    return (
        <Field>
            <FieldLabel htmlFor={id}>{label}</FieldLabel>
            <div className='relative'>
                <UserIcon className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                    id={id}
                    placeholder={placeholder}
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
