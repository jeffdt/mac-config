# Voice Samples

Verbatim review comments from Jeff's GitHub reviews (2024 and earlier).
These samples calibrate tone, structure, and severity scaling.

## 1. Quick Nit

> Unrelated to why you sent me this PR, but is this duplicate line an accident?

Source: klaviyo/k-repo [https://github.com/klaviyo/k-repo/pull/5628#discussion_r1873341502](https://github.com/klaviyo/k-repo/pull/5628#discussion_r1873341502)

## 2. Nit with Suggestion

> Thoughts on moving this from `services/internal/support_portal.py` to a brand new `services/support/` dir?

(After discussion:)

> My preference would be to move this new `SupportTicketDashboardService` class to a new standalone module in `/services/support`, and leave the rest of the support portal code here for now. Eventually we should move all support code there but I'm hesitant to take that on now and complicate this PR further

Source: klaviyo/app [https://github.com/klaviyo/app/pull/77101#discussion_r1863849663](https://github.com/klaviyo/app/pull/77101#discussion_r1863849663) and [https://github.com/klaviyo/app/pull/77101#discussion_r1863921178](https://github.com/klaviyo/app/pull/77101#discussion_r1863921178)

## 3. Observation-as-Question

> Maybe a dumb Q, but is there a way to do this that accounts for leap years (or... do we even want to)? I saw a `relativedelta()` function which does allow years as an input but not sure if that's what we'd want

Source: klaviyo/app [https://github.com/klaviyo/app/pull/66588#discussion_r1611699172](https://github.com/klaviyo/app/pull/66588#discussion_r1611699172)

## 4. Curiosity Question

> I wonder if the `/u/0/` is a user index like the gmail search I was telling you about. Have you tested it? I'd be happy to make a few proton accounts if it would be helpful. (Also wondering how common of a provider it is in general, I have heard of it but don't know anyone that uses it)

Source: klaviyo/fender [https://github.com/klaviyo/fender/pull/35537#discussion_r1858602887](https://github.com/klaviyo/fender/pull/35537#discussion_r1858602887)

## 5. Short +1 with Caveat

> Looks great now! And +1 to hardcoding the check against that path instead of overengineering it with some kind mapping constant (unless/until it's needed)

Source: klaviyo/fender [https://github.com/klaviyo/fender/pull/33212#discussion_r1769067753](https://github.com/klaviyo/fender/pull/33212#discussion_r1769067753)

## 6. Concern with Follow-up Question

> I am trying to remember how state normally works. Isn't it supposed to be a random opaque value that we also set as a nonce cookie, so that when we get the response, we can compare the state query param we get back with the nonce cookie we set when we initiated the req? (Basically the exact same thing as XSRF).
>
> Maybe this isn't a concern if this whole app is VPN-required, but if that's the case, I'd probably just omit it entirely to avoid confusion.

Source: klaviyo/k-repo [https://github.com/klaviyo/k-repo/pull/5628#discussion_r1873353424](https://github.com/klaviyo/k-repo/pull/5628#discussion_r1873353424)

## 7. Detailed Technical Concern

> If the user doesn't exist, will we even call this method? I think the only way we'll get a `ZendeskUnverifiedEmailException` in the first place is if the user **does** exist. If the user doesn't exist, Zendesk will 401 on the first call.
> ```
> // API response for requests with an invalid X-On-Behalf-Of email address. No idea why the error message describes an access token
> {
>     "error": "invalid_token",
>     "error_description": "The access token provided is expired, revoked, malformed or invalid for other reasons."
> }
> ```
>
> Do we need to add a check for this issue earlier, in `ZendeskApiService._handle_exceptions()`?

(Follow-up after discussion:)

> That's true about not able to guarantee which API is being called since we're using one exception handler for all Zendesk calls. I know we talked about making a new `_handle_exceptions()`, that might solve the problem here. If we had a new handler specific to `RequestsApiService` then it doesn't really matter what specific `/requests` endpoint was being called, the error is a general indicator of a nonexistent user being used in `X-On-Behalf-Of`.
>
> To take a step back though, what I'm really getting at with this question is this: what should our behavior be if a user has never created a ticket and they access this page? We can't verify them if they don't exist. Should we create them in ZD and verify them? Or just throw an exception every time and let this continue every time they visit /support?
>
> Let's talk about it in OH today!

Source: klaviyo/app [https://github.com/klaviyo/app/pull/77642#discussion_r1881251359](https://github.com/klaviyo/app/pull/77642#discussion_r1881251359) and [https://github.com/klaviyo/app/pull/77642#discussion_r1882620064](https://github.com/klaviyo/app/pull/77642#discussion_r1882620064)

## 8. Test Coverage / Positive Lead with Gap

> So good. Look at this textbook iteration we pulled off together on these tests

Source: klaviyo/app [https://github.com/klaviyo/app/pull/77740#discussion_r1887112811](https://github.com/klaviyo/app/pull/77740#discussion_r1887112811)

(Separate PR, noting tests are great but noticing a gap:)

> Nice tests!

> Parametrized pytests would be so nice here if it was an option

Source: klaviyo/app [https://github.com/klaviyo/app/pull/75140#discussion_r1813074104](https://github.com/klaviyo/app/pull/75140#discussion_r1813074104) and [https://github.com/klaviyo/app/pull/75140#discussion_r1813076818](https://github.com/klaviyo/app/pull/75140#discussion_r1813076818)

(And a combined praise + documentation observation:)

> These tests are so good. Nails both testing the code and documenting it for others

Source: klaviyo/fender [https://github.com/klaviyo/fender/pull/35537#discussion_r1858631457](https://github.com/klaviyo/fender/pull/35537#discussion_r1858631457)

## 9. Honest Self-Correction / Updating Understanding

> Hmm... I was gonna ask if ZD 403s are actually being handled by [`ZendeskApiService._handle_exceptions()`](https://github.com/klaviyo/app/blob/d30547d1be457668020922924bfdd6e718175c37/src/learning/app/services/internal/zendesk/api.py#L515-L577) but I guess it doesn't matter? It will hit `response.raise_for_status()`, trigger the second block here, and the user gets a 404 either way. If that's correct, from a UX POV, this looks good.
>
> This does make me realize we still need to solve for security logging for 403s as [called out in the RFC](https://docs.google.com/document/d/1kQ2GQvrappdD0T0qB4OTv189QoKas5DoYRVNGS2crbk/edit?tab=t.0#bookmark=id.5z69b0rrzfji). Kenny is already touching some of the `_handle_exceptions()` code in #77642 so we should probably wait till that's merged. The logging could also be a fast follow if needed. I made a separate ticket [KOPS-4693](https://klaviyo.atlassian.net/browse/KOPS-4693) to track it!

Source: klaviyo/app [https://github.com/klaviyo/app/pull/77740#discussion_r1887113745](https://github.com/klaviyo/app/pull/77740#discussion_r1887113745)

## 10. Extended Explanation / Design Discussion

> Confirming my understanding: The intended usage here is that you instantiate the factory with the email + provider key determined from DNS lookup, and it picks the appropriate email provider and saves it to a field. The intent is to abstract away the decision making process to determine provider. You then call `getURL()` on the factory instance and it returns the correct URL for the provider it determined.
>
> Maybe a naive question, but if `getURL()` requires you to pass in a query, and the correct query is based on the provider, how does the caller know what query to pass in if the factory is abstracting away the determined email provider?

(Follow-up after response:)

> Oh, I assumed that each provider used its own proprietary query syntax (i.e. a DSL). Agreed that we definitely want to filter on the same general criteria across all providers. If the providers all use the same query syntax then it makes sense to just pass one in here, otherwise I am wondering if the abstractions end up being kind of misleading (i.e. you don't care which provider the factory chooses, until you need to query). I guess that's where you could provide a map of provider queries or something and let the factory key into which one it picked

(And later:)

> I was thinking about that as well. I'd be concerned that we're veering into overengineering territory for something that we'll be throwing away. I think the main question is whether there actually is provider-specific syntax or not. I haven't actually looked closely at existing sniper links stuff to find out though!

Source: klaviyo/fender [https://github.com/klaviyo/fender/pull/35537#discussion_r1858652102](https://github.com/klaviyo/fender/pull/35537#discussion_r1858652102), [https://github.com/klaviyo/fender/pull/35537#discussion_r1858983280](https://github.com/klaviyo/fender/pull/35537#discussion_r1858983280), and [https://github.com/klaviyo/fender/pull/35537#discussion_r1859026454](https://github.com/klaviyo/fender/pull/35537#discussion_r1859026454)

## Bonus: Review-Level Summary Comments

These show how Jeff frames overall review feedback at the PR level:

> Mostly looked at `routers/auth.py` and `services/auth.py` and have a few small comments. Overall it looks great, super clean! Nicely done

Source: klaviyo/k-repo [https://github.com/klaviyo/k-repo/pull/5628#pullrequestreview-2484846475](https://github.com/klaviyo/k-repo/pull/5628#pullrequestreview-2484846475)

> Will review more thoroughly later, but wanted to get this initial thought out quickly. Overall looks great though, can't believe how fast you slapped this together

Source: klaviyo/app [https://github.com/klaviyo/app/pull/77642#pullrequestreview-2497408179](https://github.com/klaviyo/app/pull/77642#pullrequestreview-2497408179)

> Few thoughts but LGTM! Nice work keeping this super lightweight!

Source: klaviyo/app [https://github.com/klaviyo/app/pull/77740#pullrequestreview-2506667411](https://github.com/klaviyo/app/pull/77740#pullrequestreview-2506667411)

> LGTM! Is it worth having a revert PR ready just in case?

Source: klaviyo/app [https://github.com/klaviyo/app/pull/75140#pullrequestreview-2389261729](https://github.com/klaviyo/app/pull/75140#pullrequestreview-2389261729)

## Bonus: Concern Softened by Pragmatic Resolution

> I agree with @kennymatsudo that in the off chance it does fail we should just proceed and not let this block ticket creation. I am hesitant to defend any further against S3 errors here because they should be exceedingly rare (and would almost certainly fail in the downstream write too). I'd prefer to start simple and ease into more complex defensive code as we see the need arise.

Source: klaviyo/app [https://github.com/klaviyo/app/pull/75140#discussion_r1815667657](https://github.com/klaviyo/app/pull/75140#discussion_r1815667657)

## Bonus: TIL / Learning Out Loud

> TIL about the ellipsis literal. neat! I've always done `pass`

Source: klaviyo/k-repo [https://github.com/klaviyo/k-repo/pull/5628#discussion_r1873358850](https://github.com/klaviyo/k-repo/pull/5628#discussion_r1873358850)

> I never knew about the mock syntax like `mock.PropertyMock(return_value=False)`, that's so much better than having to explicitly pass the mock in as an arg and then set the return value in the test method

Source: klaviyo/app [https://github.com/klaviyo/app/pull/73486#discussion_r1772038401](https://github.com/klaviyo/app/pull/73486#discussion_r1772038401)

## Calibration: Skill Output vs. What Jeff Actually Posted

These before/after pairs show how Jeff edited skill-drafted comments during a real review.
The consistent pattern: cut the explanation, keep just the question or suggestion.

**1. Truncation detection**

Skill draft:
> Any concerns w/ the max_tokens cap silently shipping truncated HTML here? If finish_reason="length" we'd still find <!DOCTYPE html> and slice from there but miss the closing tag. Not necessarily a blocker but wanted to flag since Haiku 4.5 + bigger reports will push against the 16k cap.

What Jeff posted:
> Any concerns w/ the max_tokens cap silently shipping truncated HTML here?

**2. UUID validation**

Skill draft:
> Nit: worth gating previous_file_id on re.fullmatch(r"[0-9a-f]{32}", ...) before calling out to S3? Tightens the contract w/ the LLM and keeps ListObjectsV2 off the hot path for garbage input.

What Jeff posted:
> Nit: Could also match on the compact UUID pattern here if you are already validating

**3. Prompt as .md**

Skill draft:
> Thoughts on pulling this out to html_design_prompt.md + functools.lru_cache(Path.read_text()) like recommendations.py does for its KB? 7KB of markdown in a .py triple-quote is gonna get gnarly to edit as the prompt grows, and GitHub's markdown preview would make designer review way easier. Not a blocker for this PR.

What Jeff posted:
> You could consider pulling this out to html_design_prompt.md + functools.lru_cache(Path.read_text()) like recommendations.py does for its KB. Would be easier for Ben/Tyler to review or even modify too!

**4. Extract helper**

Skill draft:
> _make_html_design_tool is ~190 lines doing S3 memoization + prior-html resolution + sub-agent invocation + dual-event SSE plumbing + exception mapping. The generate_file event pair is load-bearing b/c the frontend listens for it specifically, but that coupling isn't obvious here. Thoughts on pulling the file-event plumbing into an _emit_file_generation_events helper so the main body reads as resolve -> run -> emit -> return?

What Jeff posted:
> Thoughts on pulling the file-event plumbing into an _emit_file_generation_events helper so the main body reads as resolve -> run -> emit -> return?

**5. Optional ref**

Skill draft:
> Any reason for scrollContainerRef being optional? Worried if it ever ends up undefined we'd silently fall back to unconditional auto-scroll.

What Jeff posted:
> This means it's optional, right? Will it ever be null?

**6. Cross-feature interaction**

Skill draft:
> Since conversation switching is landing soon, any thoughts on how this map plays across switches? If reset() doesn't fire on switch, entries will just accumulate.

What Jeff posted:
> Will this auto-reset if you switch conversations once convo history is merged? Wondering how they'll play together since they're in diff worktrees. Maybe worth rebasing onto master once that's merged and testing
