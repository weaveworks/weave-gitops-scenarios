# Why does the dex scenario need changes to /etc/hosts?

In short, because both the Weave-Gitops app and your browser need to be able
to resolve the same URL to the dex server.

The most straight forward way to do this that I could find was to give
Weave-Gitops the [kubernetes DNS name](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#a-aaaa-records) (`dex.dex-dex.svc.cluster.local`)
and then have the developer set the same name in `/etc/hosts` to their localhost.

This set up means that Weave-Gitops can route to dex using kubernetes' internal
DNS and, as long as the developer has port-forwarding set up for dex
(`make access-dex`), the browser can be redirected to it on the localhost.

## Why is this undesirable?

Primarily: because it's a globally used file that can break a lot of things on
the user's machine, often in ways that are very tricky to debug. In addition
whilst the change is simple it's not easy to automate across OS's, especially
as it requires `sudo` (or equivalent) permissions.


## Why is this needed at all?

Because of two interlinked situations: the requirements of Dex and how
Kubernetes clusters work.

The three-way nature of the [OIDC protocol](https://dexidp.io/docs/openid-connect/)
means that both the user (well their browser) and the client-application
(Weave-Gitops) need to be able to send traffic to Dex using the same DNS name.
The DNS name requirement is because Dex doesn't respond to traffic with a `Host`
that doesn't match its configured `issuer`. Normally this isn't a problem
because this is exactly the problem DNS solves: both the client application and
the user send traffic to Dex via the internet, routed using the same DNS name.

The Kubernetes side of the problem is that any pod in a Kubernetes cluster is
its own localhost. This means that the usual way of running
[Dex for development](https://dexidp.io/docs/getting-started/), accessing it via
`localhost` wont work unless Dex runs in the same pod as Weave-Gitops.

These two constraints mean that, unlike most local development, `localhost`
isn't an option (Weave-Gitops won't see anything), Docker's inbuilt DNS doesn't
work (it's not available to the host) and you can't configure Dex with
multiple `issuer` URLs.

## What else was tried/considered?

### Running Dex in the same pod as Weave-Gitops

This was rejected as requiring a lot of custom configuration and because it
would under-cut the usefulness of the scenarios by running both Dex and
Weave-Gitops in a manner that is very non-standard.

### Public DNS

This would require any developer using the scenarios to create their own DNS
records somewhere and remember to clean them up (as well as pay for them).

### Container hosted browser

It is possible to run a [browser in Docker](https://hub.docker.com/r/jlesage/firefox)
and then serve the screen to a browser. The hosted browser could then access
both Dex and Weave-Gitops using Docker's internal DNS. This was rejected
because it's a lot of set up for a sub-optimal experience.

### Using mDNS

In theory [mDNS](https://en.wikipedia.org/wiki/MDNS) could be used to broadcast
the Dex service name via a forwarded port from Docker to mimic the change
in `/etc/hosts` but I couldn't find a suitable application to do this (and
this would likely run into problems with differences in how various OS's host
Docker networks).
