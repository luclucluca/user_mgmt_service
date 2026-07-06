import {Avatar, AvatarFallback, AvatarImage} from '@/components/ui/avatar'
import {Card, CardContent, CardDescription, CardFooter, CardTitle} from '@/components/ui/card'

const CardHorizontalDemo = () => {
  return (
    <Card className='max-w-xl border-none'>
      <CardContent>
        <p>
          Integer ac nulla suscipit, sodales sem non, consectetur mi. Duis vitae tempus ex, ac molestie metus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Suspendisse faucibus orci non tincidunt tempor. Morbi in interdum nunc, eu aliquet lorem. Phasellus id lorem vitae justo fringilla sodales.
        </p>
      </CardContent>
      <CardFooter className='justify-between gap-3 max-sm:flex-col max-sm:items-stretch'>
        <div className='flex items-center gap-3'>
          <Avatar className='ring-ring ring-2'>
            <AvatarImage src='https://cdn.shadcnstudio.com/ss-assets/avatar/avatar-5.png' alt='Hallie Richards' />
            <AvatarFallback className='text-xs'>SG</AvatarFallback>
          </Avatar>
          <div className='flex flex-col gap-0.5'>
            <CardTitle className='flex items-center gap-1 text-sm'>Sam Green</CardTitle>
            <CardDescription>Head of Markerting</CardDescription>
          </div>
        </div>
      </CardFooter>
    </Card>
  )
}

export default CardHorizontalDemo
