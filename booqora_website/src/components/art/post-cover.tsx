import Image from "next/image";
import { industryPhoto } from "@/content/industries";
import type { Post } from "@/content/posts";
import { cn } from "@/lib/utils";

const photos: Record<Post["art"], string> = {
  launch: "camera-av-rental",
  pricing: "tool-equipment-rental",
  calendar: "party-event-rental",
};

/** Photographic cover for a guide with a soft brand-tinted overlay. */
export function PostCover({ art, className, large = false }: { art: Post["art"]; className?: string; large?: boolean }) {
  return (
    <div className={cn("relative isolate overflow-hidden bg-night", className)} aria-hidden>
      <Image src={industryPhoto(photos[art])} alt="" fill sizes={large ? "(min-width: 1024px) 900px, 100vw" : "(min-width: 768px) 600px, 100vw"} className="object-cover" />
      <div className="absolute inset-0 bg-gradient-to-tr from-indigo/45 via-transparent to-transparent" />
    </div>
  );
}
