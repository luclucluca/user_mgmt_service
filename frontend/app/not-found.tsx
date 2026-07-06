import Link from "next/link"
import {Button} from "@/components/ui/button"

export default function NotFound() {
    return (
        <div className="grid min-h-svh lg:grid-cols-2">

            {/* LEFT SIDE */}
            <div className="flex flex-col justify-center px-6 py-12 md:px-10">
                <div className="mx-auto w-full max-w-md text-center lg:text-left space-y-6">

                    <h1 className="text-5xl font-bold tracking-tight">
                        Whoops!
                    </h1>

                    <h2 className="text-2xl font-semibold">
                        Something went wrong
                    </h2>

                    <p className="text-muted-foreground">
                        The page you&apos;re looking for isn&apos;t found, we suggest you back to home
                    </p>

                    <Button
                        asChild
                        className="text-lg px-4 py-5 rounded-xl"
                    >
                        <Link href="/">Back to home page</Link>
                    </Button>

                </div>
            </div>

            {/* RIGHT SIDE */}
            <div className="relative hidden lg:flex items-center justify-center bg-black">
                <img
                    src="/astronaut.webp"
                    alt="404 illustration"
                    className="relative z-10 max-h-[70%] object-contain"
                />
            </div>

        </div>
    )
}