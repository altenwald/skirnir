# Skirnir

[![Build Status](https://img.shields.io/travis/altenwald/skirnir/master.svg)](https://travis-ci.org/altenwald/skirnir)
[![Codecov](https://img.shields.io/codecov/c/github/altenwald/skirnir.svg)](https://codecov.io/gh/altenwald/skirnir)
[![License: GPL 3](https://img.shields.io/github/license/altenwald/skirnir.svg)](https://raw.githubusercontent.com/altenwald/skirnir/master/COPYING)

Skirnir is an Email Server developed in 100% pure Elixir and Erlang/OTP.

The main aim is create a complete server (SMTP, IMAP and Sieve).

If you want to see our progress you can check our [Trello](https://trello.com/b/4SRbcC8M/skirnir) board.

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=XK6Z5XATN77L2)

## Standars

This server is built following those standards for MTA, MDA and MAA.

### Mail Transfer Agent (MTA)

Basicly it's based on SMTP. Those are the standars we are using to implement it:

- [RFC-3207](https://tools.ietf.org/html/rfc3207) **SMTP Service Extension for Secure SMTP over Transport Layer Security** (TLS).
- [RFC-4954](https://tools.ietf.org/html/rfc4954) **SMTP Service Extension for Authentication**.
- [RFC-5321](https://tools.ietf.org/html/rfc5321) **Simple Mail Transfer Protocol** (SMTP).
- [RFC-5322](https://tools.ietf.org/html/rfc5322) **Internet Message Format**.

### Mail Delivery Agent (MDA)

Actually, those standards are designed to create rules to deliver the message and are not related with the way the messages are deliverd.

- [RFC-5228](https://tools.ietf.org/html/rfc5228) **Sieve: An Email Filtering Language**
- [RFC-5229](https://tools.ietf.org/html/rfc5229) **Sieve Email Filtering: Variables Extension**
- [RFC-5173](https://tools.ietf.org/html/rfc5173) **Sieve Email Filtering: Body Extension**
- [RFC-5429](https://tools.ietf.org/html/rfc5429) **Sieve Email Filtering: Reject and Extended Reject Extensions**
- [RFC-6785](https://tools.ietf.org/html/rfc6785) **Support for Internet Message Protocol (IMAP) Events in Sieve**

### Mail Access Agent (MAA)

At this moment those are the standards we want to implement. Both of them (POP3 and IMAP4) have a lot of extensions. We'll adding them when they'll be implemented.

- [RFC-3501](https://tools.ietf.org/html/rfc3501) **Internet Message Access Protocol Version 4rev1** (IMAP v4.1)
- [RFC-1939](https://tools.ietf.org/html/rfc1939) **Post Office Protocol - Version 3** (POP3)

## Installation

TBD

