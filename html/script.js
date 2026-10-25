let groupMembers = []
let groupLeaderId = null
let myServerId = null
let maxGroupSize = 4

let myName = "Unknown"
let leaderName = "Unknown"
const groupMembersEl = document.getElementById("groupMembers")
const playersListEl = document.getElementById("playersList")
const groupCountEl = document.getElementById("groupCount")


const invitePopup = document.getElementById("invitePopup")
const popupText = document.getElementById("popupText")
let currentInviteGroup = null

let currentGroupId = null

// Names come from players, never put them in innerHTML unescaped
function escapeHtml(value) {
    return String(value ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;")
}

function post(endpoint, body) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify(body || {})
    }).catch(() => {})
}

function renderGroupMembers() {
    document.querySelector(".my-avatar").innerHTML = `
          <div class="member-avatar">
                <img src="assets/group.png" alt="avatar">
            </div>
    `
    const isLeader = myServerId === groupLeaderId
    groupMembersEl.innerHTML = ""
    groupMembers.forEach(member => {
        if (!member || typeof member !== "object") return
        const isMemberLeader = member.id === groupLeaderId
        const isMe = member.id === myServerId
        const div = document.createElement("div")
        div.className = "member-card"
        div.innerHTML = `
            <div class="member-left">
            <div class="member-avatar">
                <img src="assets/player.png" alt="avatar">
            </div>
                <div class="member-info">
                    <h3>
                        ${escapeHtml(isMemberLeader ? leaderName : member.name)}
                    </h3>
                    <span>
                        ${isMemberLeader ? `Group Leader` : "Group Member"} &nbsp;·&nbsp; ID: ${escapeHtml(member.id)}
                    </span>
                </div>
            </div>
            <div class="member-right">
                ${
                    isMemberLeader ? `<div class="leader-tag">Leader</div>` : ``
                }
                ${isLeader && !isMemberLeader ? `
                    <button class="kick-btn">
                        Kick
                    </button>
                ` : ``}
                ${isMe && groupMembers.length > 1 ? `
                    <button class="kick-btn leave-btn">
                        Leave
                    </button>
                ` : ``}
            </div>
        `
        const kickBtn = div.querySelector(".kick-btn:not(.leave-btn)")
        const leaveBtn = div.querySelector(".leave-btn")
        if (leaveBtn) {
            leaveBtn.addEventListener("click", () => {
                post("leaveGroup", {})
            })
        }
        if (kickBtn) {
            kickBtn.addEventListener("click", () => {
                post("kickPlayer", {
                    playerId: member.id
                })
            })
        }
        groupMembersEl.appendChild(div)
    })
    groupCountEl.innerText = `${groupMembers.length} / ${maxGroupSize}`
}

function renderNearbyPlayers(players) {
    playersListEl.innerHTML = ""
    if (!players || players.length === 0) {
        playersListEl.innerHTML = `
            <div class="player-card">
                <div class="player-info">
                    <h2>No Nearby Players</h2>
                    <span>Move closer to players</span>
                </div>
            </div>
        `
        return
    }
    const groupFull = groupMembers.length >= maxGroupSize
    players.forEach(player => {
        const div = document.createElement("div")
        div.className = "player-card"
        let status = player.status || "invite"
        let btnLabel = status.charAt(0).toUpperCase() + status.slice(1)
        let disabled = status !== "invite" || groupFull ? "disabled" : ""
        div.innerHTML = `
                <div class="player-left">
                    <div class="member-avatar">
                        <img src="assets/player.png" alt="avatar">
                    </div>
                    <div class="player-info">
                        <h2>${escapeHtml(player.name)}</h2>
                        <span>ID: ${escapeHtml(player.id)} &nbsp;·&nbsp; ${escapeHtml(player.distance)}m Away</span>
                    </div>
                </div>
                <button class="invite-btn" ${disabled}>
                    ${escapeHtml(btnLabel)}
                </button>
            `


        div.querySelector(".invite-btn")
            .addEventListener("click", (e) => {

                if (status !== "invite" || groupFull) return

                post("invitePlayer", {
                    playerId: player.id
                })

            })
        playersListEl.appendChild(div)
    })
}


window.addEventListener("message", (event) => {
    const data = event.data
    if (data.action === "toggle") {
        document.querySelector(".group-ui")
            .style.display =
            data.state ? "block" : "none"
    }
    if (data.action === "setNearbyPlayers") {
        renderNearbyPlayers(data.players)
    }
})


window.addEventListener("message", (event) => {
    const data = event.data
    if (data.action === "setGroupMembers") {
        groupMembers = (data.members || []).map(m => ({
            ...m,
            leader: m.id === data.leader
        }))

        groupLeaderId = data.leader
        leaderName = data.leaderName
        if (data.maxSize) maxGroupSize = data.maxSize
        if (data.myId != null) myServerId = data.myId

        currentGroupId = data.groupId ?? null

        renderGroupMembers()
    }
})


document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {

        post("close")

        const inviteVisible = !invitePopup.classList.contains("hidden")

        if (inviteVisible && currentInviteGroup) {

            post("declineInvite", {
                groupId: currentInviteGroup
            })

            invitePopup.classList.add("hidden")

            currentInviteGroup = null
        }
    }

    if (e.key === "Shift" && !e.repeat) {
        post("toggleMouse")
    }
})

document.querySelector(".group-ui")
    .style.display = "none"
renderGroupMembers()


window.addEventListener("message", (event) => {
    const data = event.data
    if (data.action === "showInvite") {
        currentInviteGroup = data.groupId
        popupText.innerText = `${data.fromName} invited you to join their group.`
        invitePopup.classList.remove("hidden")
    }

    if (data.action === "hideInvite") {
        invitePopup.classList.add("hidden")
        currentInviteGroup = null
    }

    if (data.action === "setMyId") {
        myServerId = data.id
        if (groupMembers.length > 0) {
            renderGroupMembers()
        }
    }

    if (data.action === "setMyInfo") {
        myName = data.name
        document.querySelector(".my-avatar").innerHTML = `
        <img src="assets/player.png" alt="avatar">
    `
    }

})

document.getElementById("acceptBtn")
    .addEventListener("click", () => {
        post("acceptInvite", {
            groupId: currentInviteGroup
        })
        invitePopup.classList.add("hidden")
        currentInviteGroup = null
    })

document.getElementById("declineBtn")
    .addEventListener("click", () => {

        post("declineInvite", {
            groupId: currentInviteGroup
        })

        invitePopup.classList.add("hidden")
        currentInviteGroup = null

    })
