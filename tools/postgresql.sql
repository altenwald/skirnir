CREATE TABLE "public"."email" (
    "id" char(12) NOT NULL,
    "rcpt_to" varchar(128) NOT NULL,
    "mail_from" varchar(128) NOT NULL,
    "subject" text,
    "sent_at" timestamp NOT NULL DEFAULT now(),
    "headers" text NOT NULL,
    "body" text NOT NULL,
    "size" integer NOT NULL DEFAULT 0,
    "path" text NOT NULL DEFAULT 'INBOX',
    PRIMARY KEY ("id")
);
