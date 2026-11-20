#:sdk Microsoft.NET.Sdk.Web
#:property PublishAot=false
// =============================================================================
// External-05 profile API - the Beeceptor mock as ONE C# file (.NET 10).
//   dotnet run ProfileApi.cs           -> http://localhost:5087
// Same paths and answers as the Beeceptor rules:
//   POST /api/OnAttributeCollectionSubmit  -> stores the sign-up profile, continueWithDefaultBehavior
//   POST /api/OnTokenIssuanceStart         -> links the object id, provideClaimsForToken
//   GET  /api/profiles                     -> everything in memory (debug)
// Every request and response is written to the console. Profiles live in memory
// only: restart = empty. NO token validation (like Beeceptor) - workshop only.
// =============================================================================
using System.Collections.Concurrent;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.AddFilter("Microsoft", LogLevel.Warning); // console = payloads only
builder.Logging.AddFilter("Microsoft.Hosting.Lifetime", LogLevel.Information); // "Now listening on ..."
builder.WebHost.UseUrls(Environment.GetEnvironmentVariable("ASPNETCORE_URLS") ?? "http://localhost:5087");
var app = builder.Build();

var profiles = new ConcurrentDictionary<string, Profile>(StringComparer.OrdinalIgnoreCase); // key = e-mail
var json = new JsonSerializerOptions { WriteIndented = true }; // PascalCase kept (CrmId, not crmId)

// Sign-up page submitted: the user does NOT exist yet -> keyed by e-mail.
app.MapPost("/api/OnAttributeCollectionSubmit", (JsonNode body, HttpRequest req) =>
{
    Log("IN  OnAttributeCollectionSubmit", req, body);
    var attributes = body["data"]?["userSignUpInfo"]?["attributes"]?.AsObject();
    string? Attr(string name) => attributes?.FirstOrDefault(a => a.Key == name || a.Key.EndsWith("_" + name)).Value?["value"]?.ToString();

    var email = Attr("email")
        ?? body["data"]?["userSignUpInfo"]?["identities"]?[0]?["issuerAssignedId"]?.ToString()
        ?? "unknown";

    var profile = (profiles.TryGetValue(email, out var existing) ? existing : Profile.New(email)) with
    {
        GivenName = Attr("givenName"),
        Surname = Attr("surname"),
        TermsOfUseAccepted = Attr("TermsOfUseAccepted") == "true",
        PrivacyPolicyAccepted = Attr("PrivacyPolicyAccepted") == "true",
        ConsentedAt = DateTimeOffset.UtcNow,
    };
    profiles[email] = profile;
    Console.WriteLine($"     STORED profile {JsonSerializer.Serialize(profile, json)}");

    var response = new
    {
        data = new Dictionary<string, object>
        {
            ["@odata.type"] = "microsoft.graph.onAttributeCollectionSubmitResponseData",
            ["actions"] = new[] { new Dictionary<string, object> { ["@odata.type"] = "microsoft.graph.attributeCollectionSubmit.continueWithDefaultBehavior" } },
        },
    };
    return Reply("OnAttributeCollectionSubmit", response);
});

// Token about to be issued: the user exists -> link the object id, return claims.
app.MapPost("/api/OnTokenIssuanceStart", (JsonNode body, HttpRequest req) =>
{
    Log("IN  OnTokenIssuanceStart", req, body);
    var context = body["data"]?["authenticationContext"];
    var user = context?["user"];
    var objectId = user?["id"]?.ToString();
    var email = user?["mail"]?.ToString();

    // 1st: by object id; 2nd (first sign-in after sign-up): by e-mail; else create lazily
    // (users who signed up before the submit hook existed).
    var profile = profiles.Values.FirstOrDefault(p => p.ObjectId == objectId)
        ?? (email is not null && profiles.TryGetValue(email, out var byMail) ? byMail : null)
        ?? Profile.New(email ?? objectId ?? "unknown");
    profile = profile with { ObjectId = objectId, LastSignIn = DateTimeOffset.UtcNow, SignInCount = profile.SignInCount + 1 };
    profiles[profile.Email] = profile;
    Console.WriteLine($"     LINKED profile {JsonSerializer.Serialize(profile, json)}");

    var response = new
    {
        data = new Dictionary<string, object>
        {
            ["@odata.type"] = "microsoft.graph.onTokenIssuanceStartResponseData",
            ["actions"] = new[]
            {
                new Dictionary<string, object>
                {
                    ["@odata.type"] = "microsoft.graph.tokenIssuanceStart.provideClaimsForToken",
                    // Names = token_claims in external-05.tf (case-sensitive).
                    ["claims"] = new
                    {
                        CorrelationId = context?["correlationId"]?.ToString() ?? "n/a",
                        ApiVersion = "csharp-1.0",
                        profile.CrmId,
                        profile.LoyaltyNumber,
                        profile.LoyaltyTier,
                    },
                },
            },
        },
    };
    return Reply("OnTokenIssuanceStart", response);
});

app.MapGet("/api/profiles", () => profiles.Values);

app.Run();

// ---------------------------------------------------------------------------
// Console output
// ---------------------------------------------------------------------------
void Log(string title, HttpRequest req, JsonNode body)
{
    Console.WriteLine($"\n===== {DateTimeOffset.Now:HH:mm:ss} {title} =====");
    var auth = req.Headers.Authorization.ToString();
    if (auth.StartsWith("Bearer ")) // decoded, NOT validated
    {
        var payload = auth[7..].Split('.').ElementAtOrDefault(1) ?? "";
        payload = payload.Replace('-', '+').Replace('_', '/').PadRight(payload.Length + (4 - payload.Length % 4) % 4, '=');
        try { Console.WriteLine($"     Bearer token claims (not validated): {Encoding.UTF8.GetString(Convert.FromBase64String(payload))}"); }
        catch { Console.WriteLine("     Bearer token: <not decodable>"); }
    }
    else Console.WriteLine("     No bearer token");
    Console.WriteLine(body.ToJsonString(json));
}

IResult Reply(string title, object response)
{
    Console.WriteLine($"----- OUT {title} -----\n{JsonSerializer.Serialize(response, json)}");
    // Same options as the log: NO camelCase - Entra matches claim names case-sensitively.
    return Results.Json(response, json);
}

// ---------------------------------------------------------------------------
// In-memory record
// ---------------------------------------------------------------------------
record Profile(string Email)
{
    public string? ObjectId { get; init; }
    public string? GivenName { get; init; }
    public string? Surname { get; init; }
    public bool TermsOfUseAccepted { get; init; }
    public bool PrivacyPolicyAccepted { get; init; }
    public DateTimeOffset? ConsentedAt { get; init; }
    public string CrmId { get; init; } = "";
    public string LoyaltyNumber { get; init; } = "";
    public string LoyaltyTier { get; init; } = "";
    public DateTimeOffset? LastSignIn { get; init; }
    public int SignInCount { get; init; }

    public static Profile New(string email) => new(email)
    {
        CrmId = $"CRM-{Random.Shared.Next(100000, 999999)}",
        LoyaltyNumber = Random.Shared.Next(100000, 999999).ToString(),
        LoyaltyTier = new[] { "Silver", "Gold", "Platinum" }[Random.Shared.Next(3)],
    };
}
